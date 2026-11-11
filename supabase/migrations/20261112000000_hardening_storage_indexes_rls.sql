-- ============================================================================
-- Supabase Schema Migration: Ministério Pessoal — Endurecimento Final & Storage
-- Migration Version: 20261112000000_hardening_storage_indexes_rls.sql
-- Description:
--   1. Garante bucket privado ticuna_audio (e buckets privados obrigatórios).
--   2. Consolida políticas RLS de storage.objects TO authenticated com (select auth.uid()).
--   3. Consolida políticas RLS das 27 tabelas públicas TO authenticated com (select auth.uid()).
--   4. Fixa search_path = public nas funções trigger e restringe EXECUTE de sync_upsert.
--   5. Remove índices duplicados e adiciona 7 índices cobrindo FKs sem índice.
--   6. Amplia CHECK constraint de appointments.status para compatibilidade legada.
-- ============================================================================

-- 1. Buckets de Storage privados obrigatórios
INSERT INTO storage.buckets (id, name, public)
VALUES
    ('ticuna_audio', 'ticuna_audio', false),
    ('knowledge_vault', 'knowledge_vault', false),
    ('person_photos', 'person_photos', false)
ON CONFLICT (id) DO UPDATE SET public = false;

-- 2. Políticas de Storage consolidadas (TO authenticated, (select auth.uid()), sem cast UUID frágil)
DROP POLICY IF EXISTS "Users can access their own ticuna_audio storage objects" ON storage.objects;
CREATE POLICY "Users can access their own ticuna_audio storage objects"
    ON storage.objects
    FOR ALL
    TO authenticated
    USING (
        bucket_id = 'ticuna_audio'
        AND (
            (storage.foldername(name))[1] = (select auth.uid())::text
            OR owner = (select auth.uid())
        )
    )
    WITH CHECK (
        bucket_id = 'ticuna_audio'
        AND (storage.foldername(name))[1] = (select auth.uid())::text
    );

DROP POLICY IF EXISTS "Users can access their own knowledge_vault storage objects" ON storage.objects;
CREATE POLICY "Users can access their own knowledge_vault storage objects"
    ON storage.objects
    FOR ALL
    TO authenticated
    USING (
        bucket_id = 'knowledge_vault'
        AND (
            (storage.foldername(name))[1] = (select auth.uid())::text
            OR owner = (select auth.uid())
        )
    )
    WITH CHECK (
        bucket_id = 'knowledge_vault'
        AND (storage.foldername(name))[1] = (select auth.uid())::text
    );

DROP POLICY IF EXISTS "Users can access their own person_photos storage objects" ON storage.objects;
CREATE POLICY "Users can access their own person_photos storage objects"
    ON storage.objects
    FOR ALL
    TO authenticated
    USING (
        bucket_id = 'person_photos'
        AND (
            (storage.foldername(name))[1] = (select auth.uid())::text
            OR owner = (select auth.uid())
        )
    )
    WITH CHECK (
        bucket_id = 'person_photos'
        AND (storage.foldername(name))[1] = (select auth.uid())::text
    );

DROP POLICY IF EXISTS "voice_notes_storage_select" ON storage.objects;
DROP POLICY IF EXISTS "voice_notes_storage_insert" ON storage.objects;
DROP POLICY IF EXISTS "voice_notes_storage_update" ON storage.objects;
DROP POLICY IF EXISTS "voice_notes_storage_delete" ON storage.objects;
DROP POLICY IF EXISTS "Users can access their own voice_notes storage objects" ON storage.objects;
CREATE POLICY "Users can access their own voice_notes storage objects"
    ON storage.objects
    FOR ALL
    TO authenticated
    USING (
        bucket_id IN ('voice_notes', 'voice-notes')
        AND (
            (storage.foldername(name))[1] = (select auth.uid())::text
            OR owner = (select auth.uid())
        )
    )
    WITH CHECK (
        bucket_id = 'voice_notes'
        AND (storage.foldername(name))[1] = (select auth.uid())::text
    );

-- 3. Consolidação de políticas RLS nas 27 tabelas públicas ((select auth.uid()) + TO authenticated)
DO $$
DECLARE
    tbl text;
    all_tables text[] := ARRAY[
        'people', 'visits', 'bible_studies', 'study_participants',
        'study_sessions', 'appointments', 'activity_records', 'sync_queue',
        'voice_notes', 'phone_contacts', 'territory_landmarks',
        'family_ties', 'ministry_experiences', 'person_photos',
        'person_publications', 'research_articles', 'research_tags',
        'territory_sectors', 'inbox_entries', 'projects', 'tasks',
        'knowledge_notes', 'knowledge_questions', 'knowledge_documents',
        'knowledge_resources', 'ticuna_words', 'ticuna_phrases'
    ];
BEGIN
    FOREACH tbl IN ARRAY all_tables LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', tbl);
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'Users can manage their own ' || tbl, tbl);
        EXECUTE format('DROP POLICY IF EXISTS %I_select_policy ON public.%I', tbl, tbl);
        EXECUTE format('DROP POLICY IF EXISTS %I_insert_policy ON public.%I', tbl, tbl);
        EXECUTE format('DROP POLICY IF EXISTS %I_update_policy ON public.%I', tbl, tbl);
        EXECUTE format('DROP POLICY IF EXISTS %I_delete_policy ON public.%I', tbl, tbl);
        EXECUTE format('DROP POLICY IF EXISTS %I_user_policy ON public.%I', tbl, tbl);
        EXECUTE format(
            'CREATE POLICY %I_user_policy ON public.%I
             FOR ALL
             TO authenticated
             USING ((select auth.uid()) = owner_id)
             WITH CHECK ((select auth.uid()) = owner_id)',
            tbl, tbl
        );
    END LOOP;
END $$;

-- 4. Endurecimento de search_path nas funções trigger e privilégios de sync_upsert
ALTER FUNCTION public.handle_update_audit() SET search_path = public;
ALTER FUNCTION public.handle_soft_delete_and_resurrection_guard() SET search_path = public;

REVOKE ALL ON FUNCTION public.sync_upsert(TEXT, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sync_upsert(TEXT, JSONB) FROM anon;
GRANT EXECUTE ON FUNCTION public.sync_upsert(TEXT, JSONB) TO authenticated, service_role;

-- 5. Índices duplicados removidos + 7 índices cobrindo chaves estrangeiras
DROP INDEX IF EXISTS public.idx_phone_contacts_owner;
DROP INDEX IF EXISTS public.idx_territory_landmarks_owner;

CREATE INDEX IF NOT EXISTS idx_appointments_previous_appointment_id ON public.appointments(previous_appointment_id);
CREATE INDEX IF NOT EXISTS idx_family_ties_person_id ON public.family_ties(person_id);
CREATE INDEX IF NOT EXISTS idx_family_ties_related_person_id ON public.family_ties(related_person_id);
CREATE INDEX IF NOT EXISTS idx_person_photos_person_id ON public.person_photos(person_id);
CREATE INDEX IF NOT EXISTS idx_person_publications_person_id ON public.person_publications(person_id);
CREATE INDEX IF NOT EXISTS idx_study_participants_owner_id ON public.study_participants(owner_id);
CREATE INDEX IF NOT EXISTS idx_study_sessions_owner_id ON public.study_sessions(owner_id);

-- 6. Compatibilidade de appointments.status com registros legados 'evento_teocratico'
ALTER TABLE public.appointments DROP CONSTRAINT IF EXISTS appointments_status_check;
ALTER TABLE public.appointments ADD CONSTRAINT appointments_status_check CHECK (
    status IN (
        'planejado', 'confirmado', 'realizado', 'cancelado',
        'nao_realizado', 'reagendado', 'provisorio', 'conflito',
        'evento_teocratico'
    )
);
