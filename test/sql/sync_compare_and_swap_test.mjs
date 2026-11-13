const { PGlite } = await import(process.env.PGLITE_MODULE ?? '@electric-sql/pglite');
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db = new PGlite();
const uid = '11111111-1111-4111-8111-111111111111';
const other = '22222222-2222-4222-8222-222222222222';
const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
await db.exec(`CREATE ROLE authenticated; CREATE ROLE anon; CREATE SCHEMA auth;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT current_setting('request.jwt.claim.sub', true)::uuid $$;
 GRANT USAGE ON SCHEMA auth TO authenticated; GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;
 CREATE TABLE public.people (id uuid PRIMARY KEY, owner_id uuid NOT NULL, name text NOT NULL, revision int NOT NULL, updated_at timestamptz NOT NULL);
 ALTER TABLE public.people ENABLE ROW LEVEL SECURITY;
 CREATE POLICY own ON public.people FOR ALL TO authenticated USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());
 GRANT SELECT, INSERT, UPDATE ON public.people TO authenticated;`);
await db.exec(readFileSync(new URL('../../supabase/migrations/20261113173516_sync_compare_and_swap.sql', import.meta.url), 'utf8'));
await db.exec(readFileSync(new URL('../../supabase/migrations/20261113175529_sync_reject_unknown_columns.sql', import.meta.url), 'utf8'));
await db.exec(`SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub', '${uid}', false);`);
async function rpc(payload, expected) {
  return (await db.query('select public.sync_upsert_if_unchanged($1,$2::jsonb,$3::jsonb) as result', ['people',JSON.stringify(payload),expected === null ? null : JSON.stringify(expected)])).rows[0].result;
}
async function get() { return (await db.query('select to_jsonb(t) as row from public.people t where id=$1', [id])).rows[0]?.row; }
const initial = {id,name:'original',revision:1,updated_at:'2026-11-01T00:00:00Z'};
assert.equal((await rpc(initial,null)).success,true);
const expected = await get();
assert.equal((await rpc({...initial,name:'concurrent',revision:2}, expected)).success,true);
assert.equal((await rpc({...initial,name:'stale',revision:9}, expected)).conflict,true);
assert.equal((await get()).name,'concurrent');
assert.equal((await rpc({...initial,name:'collision'}, null)).conflict,true);
const fresh = await get();
assert.equal((await rpc({...initial,name:'updated',revision:3}, fresh)).success,true);
assert.equal((await get()).name,'updated');
let unknownRejected = false;
try { await rpc({...initial, name:'must-not-write', nonexistent_field:'x'}, await get()); }
catch (_) { unknownRejected = true; }
assert.equal(unknownRejected, true);
assert.equal((await get()).name, 'updated');
await db.exec(`SELECT set_config('request.jwt.claim.sub', '${other}', false);`);
assert.equal(await get(),undefined);
let denied = false;
try { await rpc({...initial,name:'intruder'}, fresh); } catch (_) { denied = true; }
assert.equal(denied,true);
console.log('PASS: insert, CAS update, stale race, unknown columns rejected, insert collision, RLS/owner isolation');
await db.close();
