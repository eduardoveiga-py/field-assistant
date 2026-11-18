import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const { PGlite } = await import(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();

const user1 = '11111111-1111-4111-8111-111111111111';

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

  -- Simula a RPC legada sem CAS anteriormente exposta a authenticated
  CREATE OR REPLACE FUNCTION public.sync_upsert(p_table TEXT, p_payload JSONB)
  RETURNS JSONB
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $$
  BEGIN
    RETURN jsonb_build_object('legacy', true, 'table', p_table);
  END;
  $$;
  GRANT EXECUTE ON FUNCTION public.sync_upsert(TEXT, JSONB) TO authenticated;
`);

// Antes da migration, authenticated conseguia chamar sync_upsert legado
await db.exec(`SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '${user1}', false);`);
const before = (await db.query("SELECT public.sync_upsert('people', '{}'::jsonb) AS r")).rows[0].r;
assert.equal(before.legacy, true);

// Aplica a migration 20261118000000_revoke_legacy_sync_upsert.sql como superuser/owner
await db.exec('RESET ROLE;');
await db.exec(
  readFileSync(
    new URL('../../supabase/migrations/20261118000000_revoke_legacy_sync_upsert.sql', import.meta.url),
    'utf8',
  ),
);

// Idempotência: executar a migration duas vezes não falha
await db.exec(
  readFileSync(
    new URL('../../supabase/migrations/20261118000000_revoke_legacy_sync_upsert.sql', import.meta.url),
    'utf8',
  ),
);

// Após a migration, authenticated é recusado
await db.exec(`SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '${user1}', false);`);
await assert.rejects(
  () => db.query("SELECT public.sync_upsert('people', '{}'::jsonb)"),
  /permission denied/i,
  'authenticated must be denied EXECUTE on legacy sync_upsert(TEXT, JSONB)',
);

// Após a migration, anon é recusado
await db.exec("SET ROLE anon; SELECT set_config('request.jwt.claim.sub', '', false);");
await assert.rejects(
  () => db.query("SELECT public.sync_upsert('people', '{}'::jsonb)"),
  /permission denied/i,
  'anon must be denied EXECUTE on legacy sync_upsert(TEXT, JSONB)',
);

console.log('PASS: legacy public.sync_upsert(TEXT, JSONB) EXECUTE revoked from PUBLIC, anon, and authenticated.');
await db.close();
