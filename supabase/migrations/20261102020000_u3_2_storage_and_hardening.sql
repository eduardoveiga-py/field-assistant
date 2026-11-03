-- ============================================================================
-- Supabase Schema Migration: Ministério Pessoal — Unidade U3.2
-- Migration Version: 20261102020000_u3_2_storage_and_hardening.sql
-- Description: Endurecimento definitivo de segurança no Storage, políticas RLS,
--              compatibilidade com formatos de áudio (.mp4, .aac, .m4a) e
--              correção de timezone em colunas TIMESTAMPTZ (BUG-U3-03, BUG-U3-05, BUG-U3-10).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CORREÇÃO DE TIMEZONE EM TRIGGERS DE AUDITORIA E COLUNAS TIMESTAMPTZ (BUG-U3-05)
-- ----------------------------------------------------------------------------
-- Substitui timezone UTC legado por now() na função handle_update_audit
CREATE OR REPLACE FUNCTION public.handle_update_audit()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    IF TG_TABLE_NAME != 'sync_queue' THEN
        NEW.revision = OLD.revision + 1;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Atualização determinística dos defaults para now() em todas as colunas de auditoria TIMESTAMPTZ
ALTER TABLE public.people ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.people ALTER COLUMN updated_at SET DEFAULT now();
ALTER TABLE public.people ALTER COLUMN first_contact_at SET DEFAULT now();

ALTER TABLE public.visits ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.visits ALTER COLUMN updated_at SET DEFAULT now();

ALTER TABLE public.bible_studies ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.bible_studies ALTER COLUMN updated_at SET DEFAULT now();
ALTER TABLE public.bible_studies ALTER COLUMN started_at SET DEFAULT now();

ALTER TABLE public.study_participants ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.study_participants ALTER COLUMN updated_at SET DEFAULT now();

ALTER TABLE public.study_sessions ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.study_sessions ALTER COLUMN updated_at SET DEFAULT now();

ALTER TABLE public.appointments ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.appointments ALTER COLUMN updated_at SET DEFAULT now();

ALTER TABLE public.activity_records ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.activity_records ALTER COLUMN updated_at SET DEFAULT now();

ALTER TABLE public.voice_notes ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.voice_notes ALTER COLUMN updated_at SET DEFAULT now();

ALTER TABLE public.phone_contacts ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.phone_contacts ALTER COLUMN updated_at SET DEFAULT now();

ALTER TABLE public.territory_landmarks ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.territory_landmarks ALTER COLUMN updated_at SET DEFAULT now();

-- ----------------------------------------------------------------------------
-- 2. ENDURECIMENTO DE SEGURANÇA E SUPORTE MULTI-EXTENSÃO NO SUPABASE STORAGE (BUG-U3-03 & BUG-U3-10)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'storage') THEN
        -- 2.1 Validação de posse da nota no INSERT de áudio (BUG-U3-03)
        DROP POLICY IF EXISTS "voice_notes_storage_insert" ON storage.objects;
        CREATE POLICY "voice_notes_storage_insert" ON storage.objects
            FOR INSERT TO authenticated
            WITH CHECK (
                bucket_id = 'voice_notes' AND (
                    auth.uid() = owner OR (
                        auth.role() = 'authenticated' AND EXISTS (
                            SELECT 1 FROM public.voice_notes vn 
                            WHERE vn.id::text = regexp_replace(storage.objects.name, '\.[^.]+$', '') 
                              AND vn.owner_id = auth.uid()
                        )
                    )
                )
            );

        -- 2.2 Política de SELECT: suporte multi-extensão (.m4a, .mp4, .aac) via regexp_replace (BUG-U3-10)
        DROP POLICY IF EXISTS "voice_notes_storage_select" ON storage.objects;
        CREATE POLICY "voice_notes_storage_select" ON storage.objects
            FOR SELECT TO authenticated
            USING (
                bucket_id = 'voice_notes' AND (
                    owner = auth.uid() OR
                    auth.uid() = (
                        SELECT vn.owner_id 
                        FROM public.voice_notes vn 
                        WHERE vn.id::text = regexp_replace(storage.objects.name, '\.[^.]+$', '')
                    )
                )
            );

        -- 2.3 Política de UPDATE: suporte multi-extensão (.m4a, .mp4, .aac) via regexp_replace (BUG-U3-10)
        DROP POLICY IF EXISTS "voice_notes_storage_update" ON storage.objects;
        CREATE POLICY "voice_notes_storage_update" ON storage.objects
            FOR UPDATE TO authenticated
            USING (
                bucket_id = 'voice_notes' AND (
                    owner = auth.uid() OR
                    auth.uid() = (
                        SELECT vn.owner_id 
                        FROM public.voice_notes vn 
                        WHERE vn.id::text = regexp_replace(storage.objects.name, '\.[^.]+$', '')
                    )
                )
            )
            WITH CHECK (
                bucket_id = 'voice_notes' AND (
                    owner = auth.uid() OR
                    auth.uid() = (
                        SELECT vn.owner_id 
                        FROM public.voice_notes vn 
                        WHERE vn.id::text = regexp_replace(storage.objects.name, '\.[^.]+$', '')
                    )
                )
            );

        -- 2.4 Política de DELETE: suporte multi-extensão (.m4a, .mp4, .aac) via regexp_replace (BUG-U3-10)
        DROP POLICY IF EXISTS "voice_notes_storage_delete" ON storage.objects;
        CREATE POLICY "voice_notes_storage_delete" ON storage.objects
            FOR DELETE TO authenticated
            USING (
                bucket_id = 'voice_notes' AND (
                    owner = auth.uid() OR
                    auth.uid() = (
                        SELECT vn.owner_id 
                        FROM public.voice_notes vn 
                        WHERE vn.id::text = regexp_replace(storage.objects.name, '\.[^.]+$', '')
                    )
                )
            );
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 3. SUPORTE A STATUS DE CONFLITO EM APPOINTMENTS (AGENDA CONCORRENTE)
-- ----------------------------------------------------------------------------
-- Permite que compromissos sobrepostos pós-sincronização recebam status 'conflito'
-- sem violar a restrição de verificação CHECK na tabela appointments do Supabase.
ALTER TABLE public.appointments DROP CONSTRAINT IF EXISTS appointments_status_check;
ALTER TABLE public.appointments ADD CONSTRAINT appointments_status_check CHECK (status IN (
    'planejado', 'confirmado', 'realizado', 'cancelado', 'nao_realizado', 'reagendado', 'provisorio', 'conflito'
));

-- ============================================================================
-- SCRIPT DE ROLLBACK / REVERSÃO (se necessário):
-- ============================================================================
-- DO $$
-- BEGIN
--     IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'storage') THEN
--         DROP POLICY IF EXISTS "voice_notes_storage_insert" ON storage.objects;
--         CREATE POLICY "voice_notes_storage_insert" ON storage.objects
--             FOR INSERT TO authenticated
--             WITH CHECK (
--                 bucket_id = 'voice_notes' AND
--                 auth.role() = 'authenticated' AND
--                 (owner = auth.uid() OR owner IS NULL)
--             );
--     END IF;
-- END $$;
