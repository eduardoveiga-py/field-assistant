-- Fase 3 (FA-SEC-08 / FA-SYNC-01): Revoga acesso à RPC legada sem CAS public.sync_upsert(TEXT, JSONB).
-- Estritamente aditiva e idempotente: preserva registros existentes e bloqueia bypass de CAS/E2EE.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
          FROM pg_proc p
          JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname = 'sync_upsert'
           AND pg_get_function_identity_arguments(p.oid) = 'p_table text, p_payload jsonb'
    ) OR EXISTS (
        SELECT 1
          FROM pg_proc p
          JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname = 'sync_upsert'
           AND p.pronargs = 2
    ) THEN
        REVOKE ALL ON FUNCTION public.sync_upsert(TEXT, JSONB) FROM PUBLIC;
        REVOKE ALL ON FUNCTION public.sync_upsert(TEXT, JSONB) FROM anon;
        REVOKE ALL ON FUNCTION public.sync_upsert(TEXT, JSONB) FROM authenticated;
    END IF;
END $$;
