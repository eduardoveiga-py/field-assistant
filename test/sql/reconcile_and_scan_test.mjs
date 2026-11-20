import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const PGlite = (await import(process.env.PGLITE_MODULE || '@electric-sql/pglite')).PGlite;
const db = new PGlite();

// Setup Supabase mock environment
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

// Apply base migrations and new historical reconciliation migration
await db.exec(readFileSync(new URL('../../supabase/migrations/20261116200000_production_e2ee_tables_and_rpcs.sql', import.meta.url), 'utf8'));
await db.exec(readFileSync(new URL('../../supabase/migrations/20261117000000_e2ee_server_seq_pull_and_hardening.sql', import.meta.url), 'utf8'));
await db.exec(readFileSync(new URL('../../supabase/migrations/20261119000000_e2ee_historical_reconciliation_rpcs.sql', import.meta.url), 'utf8'));

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

// ----------------------------------------------------------------------------
// 1. Test reconcile_start() on empty account returns 0 (legacy floor)
// ----------------------------------------------------------------------------
await asUser(user1, async () => {
  const initialWatermark = (await db.query('SELECT public.encrypted_records_reconcile_start() AS w')).rows[0].w;
  assert.equal(Number(initialWatermark), 0, 'Empty account must return legacy floor 0');
});

// ----------------------------------------------------------------------------
// 2. Anon rejection on reconcile_start() and scan_page()
// ----------------------------------------------------------------------------
await asAnon(async () => {
  await assert.rejects(
    () => db.query('SELECT public.encrypted_records_reconcile_start()'),
    /42501|Autenticação obrigatória|permission denied/i,
    'anon must be rejected on reconcile_start'
  );
  await assert.rejects(
    () => db.query('SELECT * FROM public.encrypted_records_scan_page(NULL, 10)'),
    /42501|Autenticação obrigatória|permission denied/i,
    'anon must be rejected on scan_page'
  );
});

// ----------------------------------------------------------------------------
// 3. Rejection of invalid non-hex routes in scan_page with code 22023
// ----------------------------------------------------------------------------
await asUser(user1, async () => {
  const invalidRoutes = [
    'invalid-route',
    '123',
    'g'.repeat(64), // invalid hex char 'g'
    'A'.repeat(64), // uppercase hex rejected by ^[0-9a-f]{64}$
    'a'.repeat(63), // too short
    'a'.repeat(65), // too long
    "'; DROP TABLE encrypted_records; --",
  ];

  for (const badRoute of invalidRoutes) {
    await assert.rejects(
      () => db.query('SELECT * FROM public.encrypted_records_scan_page($1, 10)', [badRoute]),
      /22023|Rota hexadecimal inválida/i,
      `scan_page must reject invalid route "${badRoute}" with code 22023`
    );
  }
});

// ----------------------------------------------------------------------------
// 4. Populate records with distinct hex routes to test binary C collation
// ----------------------------------------------------------------------------
// Routes deliberately out of insertion order and mixing numbers and letters:
// In ASCII / C collation: '0' (48) < '1' (49) < '9' (57) < 'a' (97) < 'b' (98) < 'f' (102)
const testRoutes = [
  'f'.repeat(64),
  '0'.repeat(64),
  'a'.repeat(64),
  '1'.repeat(64),
  '9'.repeat(64),
  'b'.repeat(64),
];

const expectedCCollationOrder = [
  '0'.repeat(64),
  '1'.repeat(64),
  '9'.repeat(64),
  'a'.repeat(64),
  'b'.repeat(64),
  'f'.repeat(64),
];

await asUser(user1, async () => {
  for (const r of testRoutes) {
    const res = (await db.query(
      'SELECT public.encrypted_record_cas($1, 0, $2::jsonb) AS result',
      [r, JSON.stringify(validEnvelope)]
    )).rows[0].result;
    assert.equal(res.success, true);
    assert.ok(Number(res.server_seq) > 0);
  }
});

// ----------------------------------------------------------------------------
// 5. Test reconcile_start() returns accurate watermark after writes
// ----------------------------------------------------------------------------
let watermarkUser1 = 0;
await asUser(user1, async () => {
  const w = (await db.query('SELECT public.encrypted_records_reconcile_start() AS w')).rows[0].w;
  watermarkUser1 = Number(w);
  assert.equal(watermarkUser1, 6, 'Watermark must equal highest server_seq for user1 (6)');
});

// ----------------------------------------------------------------------------
// 6. Test scan_page keyset pagination ordered strictly by binary collation "C"
// ----------------------------------------------------------------------------
await asUser(user1, async () => {
  // Page 1: 2 records starting from NULL
  const p1 = (await db.query('SELECT route, revision, server_seq FROM public.encrypted_records_scan_page(NULL, 2)')).rows;
  assert.equal(p1.length, 2);
  assert.equal(p1[0].route, expectedCCollationOrder[0]);
  assert.equal(p1[1].route, expectedCCollationOrder[1]);

  // Page 2: 2 records after p1[1].route
  const p2 = (await db.query('SELECT route, revision, server_seq FROM public.encrypted_records_scan_page($1, 2)', [p1[1].route])).rows;
  assert.equal(p2.length, 2);
  assert.equal(p2[0].route, expectedCCollationOrder[2]);
  assert.equal(p2[1].route, expectedCCollationOrder[3]);

  // Page 3: 2 records after p2[1].route
  const p3 = (await db.query('SELECT route, revision, server_seq FROM public.encrypted_records_scan_page($1, 2)', [p2[1].route])).rows;
  assert.equal(p3.length, 2);
  assert.equal(p3[0].route, expectedCCollationOrder[4]);
  assert.equal(p3[1].route, expectedCCollationOrder[5]);

  // Page 4: after last route -> empty
  const p4 = (await db.query('SELECT route, revision, server_seq FROM public.encrypted_records_scan_page($1, 2)', [p3[1].route])).rows;
  assert.equal(p4.length, 0);

  // Full scan with limit = 100
  const allRows = (await db.query('SELECT route FROM public.encrypted_records_scan_page(NULL, 100)')).rows;
  assert.equal(allRows.length, expectedCCollationOrder.length);
  for (let i = 0; i < expectedCCollationOrder.length; i++) {
    assert.equal(allRows[i].route, expectedCCollationOrder[i]);
  }
});

// ----------------------------------------------------------------------------
// 7. Concurrency guarantees: write after watermark W gets server_seq > W
//    and reappears in subsequent encrypted_records_pull_since(W)
// ----------------------------------------------------------------------------
await asUser(user1, async () => {
  // Step A: Client obtains watermark W
  const W = Number((await db.query('SELECT public.encrypted_records_reconcile_start() AS w')).rows[0].w);
  assert.equal(W, watermarkUser1);

  // Step B: Write committed after obtaining watermark W
  const concurrentRoute = 'c'.repeat(64);
  const writeRes = (await db.query(
    'SELECT public.encrypted_record_cas($1, 0, $2::jsonb) AS result',
    [concurrentRoute, JSON.stringify(validEnvelope)]
  )).rows[0].result;
  assert.equal(writeRes.success, true);
  const newSeq = Number(writeRes.server_seq);
  assert.ok(newSeq > W, `Write after watermark W must have server_seq (${newSeq}) > W (${W})`);

  // Step C: Verify concurrent mutation reappears in subsequent delta pull
  const deltaRows = (await db.query(
    'SELECT route, revision, server_seq FROM public.encrypted_records_pull_since($1, 50)',
    [W]
  )).rows;
  assert.equal(deltaRows.length, 1, 'Delta pull since W must return the new concurrent write');
  assert.equal(deltaRows[0].route, concurrentRoute);
  assert.equal(Number(deltaRows[0].server_seq), newSeq);

  // Step D: Re-checking reconcile_start reflects the updated watermark
  const updatedW = Number((await db.query('SELECT public.encrypted_records_reconcile_start() AS w')).rows[0].w);
  assert.equal(updatedW, newSeq);
});

// ----------------------------------------------------------------------------
// 8. Account isolation: User 2 cannot see User 1 rows via scan_page or reconcile_start,
//    and writers of different accounts do not block each other
// ----------------------------------------------------------------------------
await asUser(user2, async () => {
  // User 2 watermark must be 0 initially
  const u2Watermark = Number((await db.query('SELECT public.encrypted_records_reconcile_start() AS w')).rows[0].w);
  assert.equal(u2Watermark, 0, 'User 2 must see watermark 0 on its own empty account');

  // User 2 scan_page must return 0 rows
  const u2Rows = (await db.query('SELECT route FROM public.encrypted_records_scan_page(NULL, 100)')).rows;
  assert.equal(u2Rows.length, 0, 'User 2 scan_page must not see any User 1 rows');

  // User 2 writes its own records without being blocked by User 1
  const u2Route = '0'.repeat(64); // same route as User 1, but owned by User 2!
  const u2Write = (await db.query(
    'SELECT public.encrypted_record_cas($1, 0, $2::jsonb) AS result',
    [u2Route, JSON.stringify(validEnvelope)]
  )).rows[0].result;
  assert.equal(u2Write.success, true);
  assert.ok(Number(u2Write.server_seq) > 0);

  // User 2 watermark is updated for User 2
  const u2NewWatermark = Number((await db.query('SELECT public.encrypted_records_reconcile_start() AS w')).rows[0].w);
  assert.equal(u2NewWatermark, Number(u2Write.server_seq));

  // User 2 scan_page returns only User 2 record
  const u2Scan = (await db.query('SELECT route FROM public.encrypted_records_scan_page(NULL, 100)')).rows;
  assert.equal(u2Scan.length, 1);
  assert.equal(u2Scan[0].route, u2Route);
});

// Verify User 1 still sees only its own records
await asUser(user1, async () => {
  const u1Scan = (await db.query('SELECT route FROM public.encrypted_records_scan_page(NULL, 100)')).rows;
  assert.equal(u1Scan.length, 7); // 6 initial + 1 concurrent
  assert.ok(!u1Scan.some((r) => r.owner_id === user2));
});

// ----------------------------------------------------------------------------
// 9. Rejection of writes without transaction counter / direct inserts
// ----------------------------------------------------------------------------
await asUser(user1, async () => {
  // Direct insert by authenticated role is denied by RLS / permissions (42501)
  await assert.rejects(
    () => db.query(
      'INSERT INTO public.encrypted_records (owner_id, route, revision, envelope) VALUES ($1, $2, 1, $3::jsonb)',
      [user1, 'e'.repeat(64), JSON.stringify(validEnvelope)]
    ),
    /permission denied|42501/i,
    'Direct INSERT into encrypted_records must be rejected with 42501'
  );

  await assert.rejects(
    () => db.query(
      'UPDATE public.encrypted_records SET revision = 99 WHERE route = $1',
      ['0'.repeat(64)]
    ),
    /permission denied|42501/i,
    'Direct UPDATE on encrypted_records must be rejected with 42501'
  );

  await assert.rejects(
    () => db.query(
      'DELETE FROM public.encrypted_records WHERE route = $1',
      ['0'.repeat(64)]
    ),
    /permission denied|42501/i,
    'Direct DELETE on encrypted_records must be rejected with 42501'
  );
});

// Internal test: verify NOT NULL constraint on server_seq (23502) and check constraint chk_encrypted_records_server_seq_positive (23514)
// Switch to superuser/postgres role to test constraint enforcement
await db.exec('RESET ROLE;');
await assert.rejects(
  () => db.query(
    'INSERT INTO public.encrypted_records (owner_id, route, revision, envelope, server_seq) VALUES ($1, $2, 1, $3::jsonb, NULL)',
    [user1, 'd'.repeat(64), JSON.stringify(validEnvelope)]
  ),
  /null value in column "server_seq"|23502/i,
  'Null server_seq must be rejected with 23502 not-null violation'
);

await assert.rejects(
  () => db.query(
    'INSERT INTO public.encrypted_records (owner_id, route, revision, envelope, server_seq) VALUES ($1, $2, 1, $3::jsonb, 0)',
    [user1, 'd'.repeat(64), JSON.stringify(validEnvelope)]
  ),
  /chk_encrypted_records_server_seq_positive|23514/i,
  'server_seq <= 0 must be rejected with 23514 check violation'
);

await assert.rejects(
  () => db.query(
    'INSERT INTO public.encrypted_records (owner_id, route, revision, envelope, server_seq) VALUES ($1, $2, 1, $3::jsonb, -5)',
    [user1, 'd'.repeat(64), JSON.stringify(validEnvelope)]
  ),
  /chk_encrypted_records_server_seq_positive|23514/i,
  'server_seq < 0 must be rejected with 23514 check violation'
);

console.log('All E2EE reconcile_start and scan_page tests passed successfully.');
