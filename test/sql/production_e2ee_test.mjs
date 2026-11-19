import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const PGlite = (await import(process.env.PGLITE_MODULE || '@electric-sql/pglite')).PGlite;
const db = new PGlite();

await db.exec(`
  DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
      CREATE ROLE authenticated;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
      CREATE ROLE anon;
    END IF;
  END $$;
  CREATE SCHEMA IF NOT EXISTS auth;
  CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid AS $$
    SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
  $$ LANGUAGE sql STABLE;
  GRANT USAGE ON SCHEMA auth TO authenticated, anon;
  GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, anon;
`);

await db.exec(readFileSync(new URL('../../supabase/migrations/20261116200000_production_e2ee_tables_and_rpcs.sql', import.meta.url), 'utf8'));
await db.exec(readFileSync(new URL('../../supabase/migrations/20261117000000_e2ee_server_seq_pull_and_hardening.sql', import.meta.url), 'utf8'));
await db.exec(readFileSync(new URL('../../supabase/migrations/20261119000000_e2ee_commit_order_cursor.sql', import.meta.url), 'utf8'));
await db.exec(readFileSync(new URL('../../supabase/migrations/20261120000000_e2ee_reconciliation_scan.sql', import.meta.url), 'utf8'));

const user1 = '11111111-1111-1111-1111-111111111111';
const user2 = '22222222-2222-2222-2222-222222222222';

const asUser = async (uid, fn) => {
  await db.exec(`SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '${uid}', false);`);
  return fn();
};

const asAnon = async (fn) => {
  await db.exec(`SET ROLE anon; SELECT set_config('request.jwt.claim.sub', '', false);`);
  return fn();
};

const validEnvelope = {
  v: 1,
  algorithm: 'A256GCM',
  nonce: '1234567890123456',
  ciphertext: 'c29tZSBjaXBoZXJ0ZXh0',
  tag: '123456789012345678901234',
};

const route1 = 'a'.repeat(64);
const route2 = 'b'.repeat(64);
const route3 = 'c'.repeat(64);

let seqAfterInsert1 = 0;
let seqAfterUpdate1 = 0;

// Test 1: Record CAS insert + monotonic server_seq + update + conflict
await asUser(user1, async () => {
  const res1 = (await db.query('SELECT public.encrypted_record_cas($1, $2, $3::jsonb) AS result', [
    route1,
    0,
    JSON.stringify(validEnvelope),
  ])).rows[0].result;
  assert.equal(res1.success, true);
  assert.equal(res1.revision, 1);
  assert.ok(Number(res1.server_seq) > 0);
  seqAfterInsert1 = Number(res1.server_seq);

  // Insert route2 and route3 for pagination tests
  const r2 = (await db.query('SELECT public.encrypted_record_cas($1, $2, $3::jsonb) AS result', [
    route2, 0, JSON.stringify(validEnvelope),
  ])).rows[0].result;
  assert.equal(r2.success, true);

  const r3 = (await db.query('SELECT public.encrypted_record_cas($1, $2, $3::jsonb) AS result', [
    route3, 0, JSON.stringify(validEnvelope),
  ])).rows[0].result;
  assert.equal(r3.success, true);

  // CAS update bumps server_seq monotonically
  const res2 = (await db.query('SELECT public.encrypted_record_cas($1, $2, $3::jsonb) AS result', [
    route1,
    1,
    JSON.stringify(validEnvelope),
  ])).rows[0].result;
  assert.equal(res2.success, true);
  assert.equal(res2.revision, 2);
  seqAfterUpdate1 = Number(res2.server_seq);
  assert.ok(seqAfterUpdate1 > Number(r3.server_seq), 'Update must advance server_seq monotonically');

  // Conflict on old revision
  const res3 = (await db.query('SELECT public.encrypted_record_cas($1, $2, $3::jsonb) AS result', [
    route1,
    1,
    JSON.stringify(validEnvelope),
  ])).rows[0].result;
  assert.equal(res3.success, false);
  assert.equal(res3.conflict, true);
  assert.equal(res3.revision, 2);

  // Test 2: Paginated pull via encrypted_records_pull_since
  const page1 = (await db.query('SELECT route, revision, server_seq FROM public.encrypted_records_pull_since(0, 2)')).rows;
  assert.equal(page1.length, 2);
  assert.equal(page1[0].route, route2);
  assert.equal(page1[1].route, route3);

  const page2 = (await db.query('SELECT route, revision, server_seq FROM public.encrypted_records_pull_since($1, 2)', [
    page1[1].server_seq,
  ])).rows;
  assert.equal(page2.length, 1);
  assert.equal(page2[0].route, route1);
  assert.equal(Number(page2[0].revision), 2);
  assert.equal(Number(page2[0].server_seq), seqAfterUpdate1);

  const page3 = (await db.query('SELECT route FROM public.encrypted_records_pull_since($1, 10)', [
    page2[0].server_seq,
  ])).rows;
  assert.equal(page3.length, 0);
});

// Test 3: Cross-user isolation (user2 cannot read user1's records)
await asUser(user2, async () => {
  const pulled = (await db.query('SELECT route FROM public.encrypted_records_pull_since(0, 100)')).rows;
  assert.equal(pulled.length, 0, 'user2 must see zero rows from user1');

  const directSelect = (await db.query('SELECT route FROM public.encrypted_records')).rows;
  assert.equal(directSelect.length, 0, 'RLS must hide user1 rows from user2');

  await assert.rejects(
    () => db.query("INSERT INTO public.encrypted_records(owner_id, route, revision, envelope) VALUES ($1, $2, 1, $3::jsonb)", [
      user2, route1, JSON.stringify(validEnvelope),
    ]),
    /permission denied/i,
  );
});

// Test 4: Anon role is denied
await asAnon(async () => {
  await assert.rejects(
    () => db.query('SELECT * FROM public.encrypted_records_pull_since(0, 10)'),
    /permission denied|Autenticação obrigatória/i,
  );
  await assert.rejects(
    () => db.query('SELECT public.encrypted_record_cas($1, 0, $2::jsonb)', [route1, JSON.stringify(validEnvelope)]),
    /permission denied|Autenticação obrigatória/i,
  );
});

// Test 5: Recovery Vault create-only & isolation
const validVaultMarker = {
  version: 1,
  vaultId: '0123456789abcdef0123456789abcdef',
  envelope: validEnvelope,
};

await asUser(user1, async () => {
  const vres1 = (await db.query('SELECT public.recovery_vault_create($1::jsonb) AS result', [
    JSON.stringify(validVaultMarker),
  ])).rows[0].result;
  assert.equal(vres1.success, true);

  const vres2 = (await db.query('SELECT public.recovery_vault_create($1::jsonb) AS result', [
    JSON.stringify(validVaultMarker),
  ])).rows[0].result;
  assert.equal(vres2.success, false);
  assert.equal(vres2.conflict, true);
});

await asUser(user2, async () => {
  const vaults = (await db.query('SELECT owner_id FROM public.recovery_vaults')).rows;
  assert.equal(vaults.length, 0, 'user2 must not see user1 recovery vault');
});

console.log('Production E2EE SQL migration tests (CAS + server_seq pull + RLS + anon deny) passed successfully.');
