-- ============================================================================
-- Field Assistant — Suíte pgTAP de Segurança RLS, E2EE RPCs e Storage Buckets
-- Executar via: `supabase test db` (FA-SEC-08 / FA-SYNC-01)
-- ============================================================================

BEGIN;

SELECT plan(31);

-- ----------------------------------------------------------------------------
-- 0. Preparação de identidades de teste (user_a e user_b) em auth.users
-- ----------------------------------------------------------------------------
INSERT INTO auth.users (id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
    ('11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', 'user_a@field-assistant.test', '{}', '{}', now(), now()),
    ('22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated', 'user_b@field-assistant.test', '{}', '{}', now(), now())
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 1. Buckets de Storage obrigatórios existem e são estritamente privados
-- ----------------------------------------------------------------------------
SELECT is(
    (SELECT count(*)::int FROM storage.buckets
      WHERE id IN ('voice_notes', 'ticuna_audio', 'knowledge_vault', 'person_photos')
        AND public = false),
    4,
    'Todos os 4 buckets de Storage existem e possuem public = false'
);

-- ----------------------------------------------------------------------------
-- 2. RPC legada sem CAS public.sync_upsert(TEXT, JSONB) revogada
-- ----------------------------------------------------------------------------
SELECT is(
    has_function_privilege('anon', 'public.sync_upsert(text, jsonb)', 'EXECUTE'),
    false,
    'Role anon não possui EXECUTE em public.sync_upsert(text, jsonb)'
);

SELECT is(
    has_function_privilege('authenticated', 'public.sync_upsert(text, jsonb)', 'EXECUTE'),
    false,
    'Role authenticated não possui EXECUTE em public.sync_upsert(text, jsonb)'
);

-- ----------------------------------------------------------------------------
-- 3. Role anon bloqueada em tabelas E2EE, RPCs E2EE e tabelas de domínio
-- ----------------------------------------------------------------------------
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', true);

SELECT throws_ok(
    $$ SELECT public.encrypted_record_cas(repeat('a', 64), 0, '{"v":1,"algorithm":"A256GCM","nonce":"1234567890123456","ciphertext":"YWJj","tag":"123456789012345678901234"}'::jsonb) $$,
    '42501',
    NULL,
    'anon é recusado em encrypted_record_cas'
);

SELECT throws_ok(
    $$ SELECT * FROM public.encrypted_records_pull_since(0, 10) $$,
    '42501',
    NULL,
    'anon é recusado em encrypted_records_pull_since'
);

SELECT throws_ok(
    $$ SELECT public.encrypted_records_reconcile_start() $$,
    '42501',
    NULL,
    'anon é recusado em encrypted_records_reconcile_start'
);

SELECT throws_ok(
    $$ SELECT * FROM public.encrypted_records_scan_page(NULL, 10) $$,
    '42501',
    NULL,
    'anon é recusado em encrypted_records_scan_page'
);

SELECT throws_ok(
    $$ SELECT public.recovery_vault_create('{"version":1,"vaultId":"0123456789abcdef0123456789abcdef","envelope":{"v":1,"algorithm":"A256GCM","nonce":"1234567890123456","ciphertext":"YWJj","tag":"123456789012345678901234"}}'::jsonb) $$,
    '42501',
    NULL,
    'anon é recusado em recovery_vault_create'
);

SELECT is(
    (SELECT count(*)::int FROM public.people),
    0,
    'anon não enxerga registros em public.people'
);

SELECT throws_ok(
    $$ INSERT INTO storage.objects(bucket_id, name) VALUES ('voice_notes', '11111111-1111-4111-8111-111111111111/anon.bin') $$,
    NULL,
    NULL,
    'anon não pode gravar em storage.objects (voice_notes)'
);

RESET ROLE;

-- ----------------------------------------------------------------------------
-- 4. Usuário A (authenticated): E2EE CAS, pull monotônico, recovery vault, domínio e 4 buckets
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);

SELECT is(
    (public.encrypted_record_cas(
        repeat('a', 64),
        0,
        '{"v":1,"algorithm":"A256GCM","nonce":"1234567890123456","ciphertext":"YWJj","tag":"123456789012345678901234"}'::jsonb
    )->>'success')::boolean,
    true,
    'user_a consegue inserir registro cifrado rev=1 via encrypted_record_cas'
);

SELECT is(
    (public.encrypted_record_cas(
        repeat('a', 64),
        1,
        '{"v":1,"algorithm":"A256GCM","nonce":"1234567890123456","ciphertext":"ZGVm","tag":"123456789012345678901234"}'::jsonb
    )->>'revision')::bigint,
    2::bigint,
    'user_a consegue atualizar registro cifrado para rev=2 via CAS'
);

SELECT is(
    (public.encrypted_record_cas(
        repeat('a', 64),
        1,
        '{"v":1,"algorithm":"A256GCM","nonce":"1234567890123456","ciphertext":"c3RhbGU=","tag":"123456789012345678901234"}'::jsonb
    )->>'conflict')::boolean,
    true,
    'encrypted_record_cas detecta conflito em revisão obsoleta'
);

SELECT is(
    (SELECT count(*)::int FROM public.encrypted_records_pull_since(0, 50)),
    1,
    'user_a lê seu próprio registro via encrypted_records_pull_since'
);

SELECT is(
    public.encrypted_records_reconcile_start() > 0,
    true,
    'user_a obtém watermark positivo via encrypted_records_reconcile_start'
);

SELECT is(
    (SELECT count(*)::int FROM public.encrypted_records_scan_page(NULL, 50)),
    1,
    'user_a lê seus registros via encrypted_records_scan_page'
);

SELECT throws_ok(
    $$ SELECT * FROM public.encrypted_records_scan_page('invalid-route', 10) $$,
    '22023',
    NULL,
    'encrypted_records_scan_page rejeita rota não hexadecimal com código 22023'
);

SELECT is(
    (public.recovery_vault_create(
        '{"version":1,"vaultId":"0123456789abcdef0123456789abcdef","envelope":{"v":1,"algorithm":"A256GCM","nonce":"1234567890123456","ciphertext":"YWJj","tag":"123456789012345678901234"}}'::jsonb
    )->>'success')::boolean,
    true,
    'user_a cria seu recovery vault com sucesso'
);

SELECT is(
    (public.recovery_vault_create(
        '{"version":1,"vaultId":"0123456789abcdef0123456789abcdef","envelope":{"v":1,"algorithm":"A256GCM","nonce":"1234567890123456","ciphertext":"YWJj","tag":"123456789012345678901234"}}'::jsonb
    )->>'conflict')::boolean,
    true,
    'recovery_vault_create é create-once e retorna conflict em segunda tentativa'
);

SELECT throws_ok(
    $$ INSERT INTO public.encrypted_records(owner_id, route, revision, envelope)
       VALUES ('11111111-1111-4111-8111-111111111111', repeat('b', 64), 1, '{}'::jsonb) $$,
    '42501',
    NULL,
    'authenticated não tem INSERT direto em public.encrypted_records (obrigatório via RPC CAS)'
);

-- Storage: user_a grava objetos cifrados sob seu prefixo nos 4 buckets
INSERT INTO storage.objects(bucket_id, name, owner)
VALUES
    ('voice_notes', '11111111-1111-4111-8111-111111111111/vn1.manifest.json', '11111111-1111-4111-8111-111111111111'),
    ('ticuna_audio', '11111111-1111-4111-8111-111111111111/tw1.manifest.json', '11111111-1111-4111-8111-111111111111'),
    ('knowledge_vault', '11111111-1111-4111-8111-111111111111/doc1.manifest.json', '11111111-1111-4111-8111-111111111111'),
    ('person_photos', '11111111-1111-4111-8111-111111111111/ph1.manifest.json', '11111111-1111-4111-8111-111111111111');

SELECT is(
    (SELECT count(*)::int FROM storage.objects
      WHERE bucket_id IN ('voice_notes', 'ticuna_audio', 'knowledge_vault', 'person_photos')
        AND name LIKE '11111111-1111-4111-8111-111111111111/%'),
    4,
    'user_a lê seus 4 objetos nos 4 buckets de Storage'
);

-- ----------------------------------------------------------------------------
-- 5. Usuário B (cross-user isolation): isolamento estrito em E2EE, vault e 4 buckets
-- ----------------------------------------------------------------------------
SELECT set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);

SELECT is(
    (SELECT count(*)::int FROM public.encrypted_records_pull_since(0, 100)),
    0,
    'user_b não recebe registros de user_a via encrypted_records_pull_since'
);

SELECT is(
    public.encrypted_records_reconcile_start(),
    0::bigint,
    'user_b obtém piso legado 0 via encrypted_records_reconcile_start'
);

SELECT is(
    (SELECT count(*)::int FROM public.encrypted_records_scan_page(NULL, 100)),
    0,
    'user_b não recebe registros de user_a via encrypted_records_scan_page'
);

SELECT is(
    (SELECT count(*)::int FROM public.encrypted_records),
    0,
    'RLS bloqueia leitura cross-user em public.encrypted_records'
);

SELECT is(
    (SELECT count(*)::int FROM public.recovery_vaults),
    0,
    'RLS bloqueia leitura cross-user em public.recovery_vaults'
);

SELECT is(
    (SELECT count(*)::int FROM storage.objects
      WHERE bucket_id IN ('voice_notes', 'ticuna_audio', 'knowledge_vault', 'person_photos')),
    0,
    'RLS bloqueia leitura cross-user nos 4 buckets de Storage'
);

SELECT throws_ok(
    $$ INSERT INTO storage.objects(bucket_id, name, owner)
       VALUES ('voice_notes', '11111111-1111-4111-8111-111111111111/evil.bin', '22222222-2222-4222-8222-222222222222') $$,
    NULL,
    NULL,
    'user_b não pode gravar no prefixo de user_a em voice_notes'
);

SELECT throws_ok(
    $$ INSERT INTO storage.objects(bucket_id, name, owner)
       VALUES ('ticuna_audio', '11111111-1111-4111-8111-111111111111/evil.bin', '22222222-2222-4222-8222-222222222222') $$,
    NULL,
    NULL,
    'user_b não pode gravar no prefixo de user_a em ticuna_audio'
);

SELECT throws_ok(
    $$ INSERT INTO storage.objects(bucket_id, name, owner)
       VALUES ('knowledge_vault', '11111111-1111-4111-8111-111111111111/evil.bin', '22222222-2222-4222-8222-222222222222') $$,
    NULL,
    NULL,
    'user_b não pode gravar no prefixo de user_a em knowledge_vault'
);

SELECT throws_ok(
    $$ INSERT INTO storage.objects(bucket_id, name, owner)
       VALUES ('person_photos', '11111111-1111-4111-8111-111111111111/evil.bin', '22222222-2222-4222-8222-222222222222') $$,
    NULL,
    NULL,
    'user_b não pode gravar no prefixo de user_a em person_photos'
);

RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
