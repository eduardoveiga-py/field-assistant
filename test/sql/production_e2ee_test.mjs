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

const user1 = '11111111-1111-1111-1111-111111111111';
const user2 = '22222222-2222-2222-2222-222222222222';

const asUser = async (uid, fn) => {
  await db.exec(`SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '${uid}', false);`);
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

// Test 1: Record CAS insert
await asUser(user1, async () => {
  const res1 = (await db.query('SELECT public.encrypted_record_cas($1, $2, $3::jsonb) AS result', [
    route1,
    0,
    JSON.stringify(validEnvelope),
  ])).rows[0].result;
  assert.equal(res1.success, true);
  assert.equal(res1.revision, 1);

  // CAS update
  const res2 = (await db.query('SELECT public.encrypted_record_cas($1, $2, $3::jsonb) AS result', [
    route1,
    1,
    JSON.stringify(validEnvelope),
  ])).rows[0].result;
  assert.equal(res2.success, true);
  assert.equal(res2.revision, 2);

  // Conflict on old revision
  const res3 = (await db.query('SELECT public.encrypted_record_cas($1, $2, $3::jsonb) AS result', [
    route1,
    1,
    JSON.stringify(validEnvelope),
  ])).rows[0].result;
  assert.equal(res3.success, false);
  assert.equal(res3.conflict, true);
  assert.equal(res3.revision, 2);
});

// Test 2: Recovery Vault create-only
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

  // Second creation for same user fails with conflict
  const vres2 = (await db.query('SELECT public.recovery_vault_create($1::jsonb) AS result', [
    JSON.stringify(validVaultMarker),
  ])).rows[0].result;
  assert.equal(vres2.success, false);
  assert.equal(vres2.conflict, true);
});

console.log('Production E2EE SQL migration tests passed successfully.');
