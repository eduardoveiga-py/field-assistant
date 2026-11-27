-- Habilita publicação Supabase Realtime para public.encrypted_records (E2EE zero-plaintext).
-- Estritamente aditiva e idempotente. O RLS existente (owner_id = auth.uid()) já restringe
-- os eventos aos registros do próprio usuário autenticado.

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        IF NOT EXISTS (
            SELECT 1
            FROM pg_publication_tables
            WHERE pubname = 'supabase_realtime'
              AND schemaname = 'public'
              AND tablename = 'encrypted_records'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.encrypted_records;
        END IF;
    END IF;
END $$;
