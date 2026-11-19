// Starts its own temporary PostgreSQL cluster using a private Unix socket only.
// Never accepts a database URL or connects to an existing cluster.
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import pg from 'pg';

const bin = resolve(process.env.FA_TEST_POSTGRES_BIN || 'node_modules/@embedded-postgres/linux-x64/native/bin');
const root = await mkdtemp(join(tmpdir(), 'field-assistant-cursor-'));
const data = join(root, 'cluster');
const port = 55439; // private socket directory makes the name unique
const migrations = resolve('supabase/migrations');
const clients = [];
let server;
const sleep = (ms) => new Promise((resolveDelay) => setTimeout(resolveDelay, ms));
const queryFile = async (client, name) => client.query(await readFile(join(migrations, name), 'utf8'));
const uid1 = '11111111-1111-4111-8111-111111111111';
const uid2 = '22222222-2222-4222-8222-222222222222';
const route = (c) => c.repeat(64);
const envelope = JSON.stringify({v: 1, algorithm: 'A256GCM', nonce: '1234567890123456', tag: '123456789012345678901234', ciphertext: 'c29tZXRoaW5n'});
async function connect() {
  const client = new pg.Client({host: root, port, user: 'postgres', database: 'postgres', connectionTimeoutMillis: 2000});
  await client.connect();
  await client.query("SET statement_timeout = '10s'");
  clients.push(client);
  return client;
}
async function user(client, uid) {
  await client.query('SET ROLE authenticated');
  await client.query("SELECT set_config('request.jwt.claim.sub', $1, false)", [uid]);
}
async function cas(client, key, expected = 0) {
  return (await client.query('SELECT public.encrypted_record_cas($1, $2, $3::jsonb) AS result', [key, expected, envelope])).rows[0].result;
}
async function pull(client, since = 0) {
  return (await client.query('SELECT route, server_seq FROM public.encrypted_records_pull_since($1, 100)', [since])).rows;
}
async function waitBlocked(admin, waiterPid, blockerPid) {
  const end = Date.now() + 5000;
  while (Date.now() < end) {
    const blockers = (await admin.query('SELECT pg_blocking_pids($1) AS pids', [waiterPid])).rows[0].pids;
    if (blockers.includes(blockerPid)) return;
    await sleep(20);
  }
  throw new Error('Expected transaction lock did not appear within 5 seconds');
}

try {
  const init = spawnSync(join(bin, 'initdb'), ['-D', data, '-U', 'postgres', '-A', 'trust', '--no-locale', '--encoding=UTF8'], {encoding: 'utf8'});
  if (init.status !== 0) throw new Error(`initdb failed: ${init.stderr || init.stdout}`);
  // The socket is private to a fresh 0700 directory. No TCP listener is used.
  server = spawn(join(bin, 'postgres'), ['-D', data, '-k', root, '-h', '', '-p', String(port)], {stdio: ['ignore', 'ignore', 'pipe']});
  let serverLog = '';
  server.stderr.on('data', (dataChunk) => { serverLog += dataChunk.toString().slice(-10000); });
  await writeFile(join(root, 'test-only-marker'), 'fictional data only\n');
  let admin;
  for (let n = 0; n < 100; n++) {
    try { admin = await connect(); break; } catch (_) { await sleep(50); }
  }
  if (!admin) throw new Error(`PostgreSQL startup failed: ${serverLog.slice(-3000)}`);
  await admin.query(`CREATE ROLE authenticated; CREATE ROLE anon; CREATE SCHEMA auth;
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
      SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    GRANT USAGE ON SCHEMA auth TO authenticated, anon;
    GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, anon;`);
  await queryFile(admin, '20261116200000_production_e2ee_tables_and_rpcs.sql');
  await queryFile(admin, '20261117000000_e2ee_server_seq_pull_and_hardening.sql');
  const a = await connect(), b = await connect(), reader = await connect(), other = await connect(), monitor = await connect();
  await user(a, uid1); await user(b, uid1); await user(reader, uid1); await user(other, uid2);

  // Characterize the old defect with actual independent sessions and MVCC.
  await a.query('BEGIN');
  const legacyA = await cas(a, route('a'));
  const legacyB = await cas(b, route('b'));
  assert.ok(legacyA.server_seq < legacyB.server_seq);
  const observed = await pull(reader);
  assert.deepEqual(observed.map((r) => r.route), [route('b')]);
  await a.query('COMMIT');
  assert.deepEqual(await pull(reader, legacyB.server_seq), [], 'old cursor skips committed A');
  console.log('PASS: reproduced legacy commit-order cursor loss');

  // The migration must wait for a pre-existing legacy writer. This makes
  // its recorded baseline cover values that are committed before cutover.
  await a.query('BEGIN');
  const inFlight = await cas(a, route('0'));
  const migrate = queryFile(admin, '20261119000000_e2ee_commit_order_cursor.sql');
  await waitBlocked(monitor, admin.processID, a.processID);
  await a.query('COMMIT');
  await migrate;
  const baseline = Number((await admin.query('SELECT legacy_floor FROM public.encrypted_record_cursor_baseline')).rows[0].legacy_floor);
  assert.ok(baseline >= inFlight.server_seq);
  // Simulate a stale, privileged legacy UPDATE after cutover: it cannot use
  // nextval directly without the new transactional owner cursor.
  await assert.rejects(() => admin.query(`UPDATE public.encrypted_records SET
    server_seq = nextval('public.encrypted_records_server_seq_seq')
    WHERE owner_id = $1 AND route = $2`, [uid1, route('a')]), /sem cursor transacional/i);
  assert.equal((await pull(reader)).length, 3, 'migration preserves preexisting encrypted records');
  console.log('PASS: migration waits for in-flight legacy writes and preserves them');
  await assert.rejects(() => reader.query('SELECT * FROM public.encrypted_record_owner_cursors'), /permission denied/i);
  await assert.rejects(() => reader.query('SELECT * FROM public.encrypted_record_cursor_baseline'), /permission denied/i);
  await assert.rejects(() => reader.query('INSERT INTO public.encrypted_records(owner_id, route, revision, envelope) VALUES ($1, $2, 1, $3::jsonb)', [uid1, route('f'), envelope]), /permission denied/i);
  await assert.rejects(() => admin.query('INSERT INTO public.encrypted_records(owner_id, route, revision, envelope) VALUES ($1, $2, 1, $3::jsonb)', [uid1, route('f'), envelope]), /sem cursor transacional/i);

  // A has allocated a cursor but has not committed. B cannot allocate/commit a
  // newer cursor for the same account, and unrelated accounts remain free.
  await a.query('BEGIN');
  const fixedA = await cas(a, route('c'));
  assert.ok(fixedA.server_seq > baseline);
  await b.query('BEGIN');
  const pending = cas(b, route('d'));
  await waitBlocked(admin, b.processID, a.processID);
  const anotherAccount = await cas(other, route('e'));
  assert.equal(anotherAccount.success, true);
  assert.deepEqual(await pull(reader, baseline), []);
  await a.query('COMMIT');
  const fixedB = await pending;
  await b.query('COMMIT');
  assert.ok(fixedB.server_seq > fixedA.server_seq);
  const fixedRows = await pull(reader, baseline);
  assert.deepEqual(fixedRows.map((r) => r.route), [route('c'), route('d')]);
  assert.deepEqual((await pull(other)).map((r) => r.route), [route('e')]);
  assert.deepEqual((await pull(reader, fixedA.server_seq)).map((r) => r.route), [route('d')]);
  const page1 = (await reader.query('SELECT route, server_seq FROM public.encrypted_records_pull_since($1, 1)', [baseline])).rows;
  const page2 = (await reader.query('SELECT route, server_seq FROM public.encrypted_records_pull_since($1, 1)', [page1[0].server_seq])).rows;
  assert.deepEqual([page1[0].route, page2[0].route], [route('c'), route('d')]);
  console.log('PASS: same-owner writes serialize; different owner progresses; paginated pull sees both');

  // Rollback releases the lock and must not leave a visible or phantom cursor.
  await a.query('BEGIN');
  await cas(a, route('f'));
  await b.query('BEGIN');
  const afterRollback = cas(b, route('1'));
  await waitBlocked(admin, b.processID, a.processID);
  await a.query('ROLLBACK');
  const after = await afterRollback;
  await b.query('COMMIT');
  assert.ok(after.server_seq > fixedB.server_seq);
  assert.deepEqual((await pull(reader, fixedB.server_seq)).map((r) => r.route), [route('1')]);
  const conflict = await cas(a, route('c'), 0);
  assert.equal(conflict.conflict, true);
  assert.equal(conflict.revision, 1);
  const updated = await cas(a, route('c'), 1);
  assert.equal(updated.revision, 2);
  assert.ok(updated.server_seq > after.server_seq);
  const updatedRows = await pull(reader, after.server_seq);
  assert.deepEqual(updatedRows.map((r) => r.route), [route('c')]);
  assert.equal((await pull(other)).length, 1);
  // Concurrent CAS on the same record: the stale update must not overwrite.
  await a.query('BEGIN');
  const winner = await cas(a, route('c'), 2);
  await b.query('BEGIN');
  const stale = cas(b, route('c'), 2);
  await waitBlocked(admin, b.processID, a.processID);
  await a.query('COMMIT');
  const staleResult = await stale;
  await b.query('COMMIT');
  assert.equal(winner.revision, 3);
  assert.equal(staleResult.conflict, true);
  assert.equal(staleResult.revision, 3);
  assert.equal((await reader.query('SELECT revision FROM public.encrypted_records WHERE route = $1', [route('c')])).rows[0].revision, '3');
  console.log('PASS: rollback, concurrent CAS conflict/update and account isolation');

  // Reapplying cannot decrease an existing cursor or discard ciphertext.
  await queryFile(admin, '20261119000000_e2ee_commit_order_cursor.sql');
  const next = await cas(a, route('2'));
  assert.ok(next.server_seq > winner.server_seq);
  await admin.query('UPDATE public.encrypted_record_owner_cursors SET last_seq = 9007199254740991 WHERE owner_id = $1', [uid1]);
  await assert.rejects(() => cas(a, route('3')), /Cursor cifrado esgotado/);
  assert.ok(!(await pull(reader)).some((r) => r.route === route('3')));
  await admin.query('SET ROLE anon');
  await assert.rejects(() => admin.query('SELECT public.encrypted_record_cas($1, 0, $2::jsonb)', [route('4'), envelope]), /permission denied/i);
  await admin.query('RESET ROLE');
  console.log('PASS: migration reapply, max-safe-integer overflow and anonymous denial');
} finally {
  await Promise.all(clients.map((client) => client.end().catch(() => {})));
  if (server) {
    if (server.exitCode === null && server.signalCode === null) {
      const exited = new Promise((resolveExit) => server.once('exit', resolveExit));
      server.kill('SIGTERM');
      const timer = setTimeout(() => server.kill('SIGKILL'), 5000);
      await exited;
      clearTimeout(timer);
    }
  }
  await rm(root, {recursive: true, force: true});
}
