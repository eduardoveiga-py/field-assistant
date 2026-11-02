-- ============================================================================
-- Supabase Schema Migration: Ministério Pessoal — Unidade U3
-- Migration Version: 20261102000000_u3_missing_tables_storage.sql
-- Description: Criação das tabelas faltantes (voice_notes, phone_contacts,
--              territory_landmarks), bucket privado de áudio e políticas RLS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TABELA: voice_notes (Notas de Voz e Ditados com Metadados Teocráticos)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.voice_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE CASCADE,
    visit_id UUID REFERENCES public.visits(id) ON DELETE SET NULL,
    study_id UUID REFERENCES public.bible_studies(id) ON DELETE SET NULL,
    audio_duration_seconds INTEGER NOT NULL DEFAULT 0,
    transcription TEXT NOT NULL DEFAULT '',
    detected_lesson INTEGER,
    detected_point INTEGER,
    extracted_pending_doubt TEXT,
    extracted_empathy_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);

-- Índices para voice_notes
CREATE INDEX IF NOT EXISTS idx_voice_notes_owner_id ON public.voice_notes(owner_id);
CREATE INDEX IF NOT EXISTS idx_voice_notes_person_id ON public.voice_notes(person_id);
CREATE INDEX IF NOT EXISTS idx_voice_notes_visit_id ON public.voice_notes(visit_id);
CREATE INDEX IF NOT EXISTS idx_voice_notes_study_id ON public.voice_notes(study_id);
CREATE INDEX IF NOT EXISTS idx_voice_notes_deleted_at ON public.voice_notes(deleted_at);
CREATE INDEX IF NOT EXISTS idx_voice_notes_updated_at ON public.voice_notes(updated_at);

-- ----------------------------------------------------------------------------
-- 2. TABELA: phone_contacts (Contatos Telefônicos e Informais)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.phone_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    secondary_phone TEXT,
    has_whatsapp BOOLEAN NOT NULL DEFAULT false,
    whatsapp_info TEXT,
    has_social BOOLEAN NOT NULL DEFAULT false,
    social_platform TEXT,
    social_handle TEXT,
    notes TEXT,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    origin TEXT NOT NULL DEFAULT 'Informal',
    converted_person_id UUID REFERENCES public.people(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);

-- Índices para phone_contacts
CREATE INDEX IF NOT EXISTS idx_phone_contacts_owner_id ON public.phone_contacts(owner_id);
CREATE INDEX IF NOT EXISTS idx_phone_contacts_phone ON public.phone_contacts(phone);
CREATE INDEX IF NOT EXISTS idx_phone_contacts_converted_person ON public.phone_contacts(converted_person_id);
CREATE INDEX IF NOT EXISTS idx_phone_contacts_deleted_at ON public.phone_contacts(deleted_at);
CREATE INDEX IF NOT EXISTS idx_phone_contacts_updated_at ON public.phone_contacts(updated_at);

-- ----------------------------------------------------------------------------
-- 3. TABELA: territory_landmarks (Pontos de Referência de Território)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.territory_landmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'outro',
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);

-- Índices para territory_landmarks
CREATE INDEX IF NOT EXISTS idx_territory_landmarks_owner_id ON public.territory_landmarks(owner_id);
CREATE INDEX IF NOT EXISTS idx_territory_landmarks_category ON public.territory_landmarks(category);
CREATE INDEX IF NOT EXISTS idx_territory_landmarks_deleted_at ON public.territory_landmarks(deleted_at);
CREATE INDEX IF NOT EXISTS idx_territory_landmarks_updated_at ON public.territory_landmarks(updated_at);

-- ----------------------------------------------------------------------------
-- 4. ROW-LEVEL SECURITY (RLS) POLICIES — TABELAS DE DADOS
-- ----------------------------------------------------------------------------
ALTER TABLE public.voice_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.phone_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.territory_landmarks ENABLE ROW LEVEL SECURITY;

-- Políticas explícitas para voice_notes
DROP POLICY IF EXISTS voice_notes_select_policy ON public.voice_notes;
CREATE POLICY voice_notes_select_policy ON public.voice_notes
    FOR SELECT TO authenticated
    USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS voice_notes_insert_policy ON public.voice_notes;
CREATE POLICY voice_notes_insert_policy ON public.voice_notes
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS voice_notes_update_policy ON public.voice_notes;
CREATE POLICY voice_notes_update_policy ON public.voice_notes
    FOR UPDATE TO authenticated
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS voice_notes_delete_policy ON public.voice_notes;
CREATE POLICY voice_notes_delete_policy ON public.voice_notes
    FOR DELETE TO authenticated
    USING (auth.uid() = owner_id);

-- Políticas explícitas para phone_contacts
DROP POLICY IF EXISTS phone_contacts_select_policy ON public.phone_contacts;
CREATE POLICY phone_contacts_select_policy ON public.phone_contacts
    FOR SELECT TO authenticated
    USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS phone_contacts_insert_policy ON public.phone_contacts;
CREATE POLICY phone_contacts_insert_policy ON public.phone_contacts
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS phone_contacts_update_policy ON public.phone_contacts;
CREATE POLICY phone_contacts_update_policy ON public.phone_contacts
    FOR UPDATE TO authenticated
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS phone_contacts_delete_policy ON public.phone_contacts;
CREATE POLICY phone_contacts_delete_policy ON public.phone_contacts
    FOR DELETE TO authenticated
    USING (auth.uid() = owner_id);

-- Políticas explícitas para territory_landmarks
DROP POLICY IF EXISTS territory_landmarks_select_policy ON public.territory_landmarks;
CREATE POLICY territory_landmarks_select_policy ON public.territory_landmarks
    FOR SELECT TO authenticated
    USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS territory_landmarks_insert_policy ON public.territory_landmarks;
CREATE POLICY territory_landmarks_insert_policy ON public.territory_landmarks
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS territory_landmarks_update_policy ON public.territory_landmarks;
CREATE POLICY territory_landmarks_update_policy ON public.territory_landmarks
    FOR UPDATE TO authenticated
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS territory_landmarks_delete_policy ON public.territory_landmarks;
CREATE POLICY territory_landmarks_delete_policy ON public.territory_landmarks
    FOR DELETE TO authenticated
    USING (auth.uid() = owner_id);

-- ----------------------------------------------------------------------------
-- 5. TRIGGER DE AUDITORIA (updated_at e revision)
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    tbl text;
    tables text[] := ARRAY['voice_notes', 'phone_contacts', 'territory_landmarks'];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trigger_%I_audit ON public.%I', tbl, tbl);
        EXECUTE format('
            CREATE TRIGGER trigger_%I_audit
            BEFORE UPDATE ON public.%I
            FOR EACH ROW
            EXECUTE FUNCTION public.handle_update_audit();
        ', tbl, tbl);
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 6. SUPABASE STORAGE: BUCKET PRIVADO voice_notes E POLÍTICAS RLS
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'storage') THEN
        -- 1. Criação do bucket privado com limite de 10MB e restrição de tipos de áudio
        INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
        VALUES (
            'voice_notes',
            'voice_notes',
            false,
            10485760, -- 10 MB máximo por arquivo de áudio
            ARRAY['audio/m4a', 'audio/x-m4a', 'audio/mp4', 'audio/aac']
        )
        ON CONFLICT (id) DO UPDATE SET
            public = false,
            file_size_limit = 10485760,
            allowed_mime_types = ARRAY['audio/m4a', 'audio/x-m4a', 'audio/mp4', 'audio/aac'];

        -- 2. Habilitação de RLS na tabela de objetos do Storage
        ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

        -- 3. Políticas de Storage por Usuário
        -- Leitura / Download: somente o dono do objeto ou dono da nota de voz vinculada
        DROP POLICY IF EXISTS "voice_notes_storage_select" ON storage.objects;
        CREATE POLICY "voice_notes_storage_select" ON storage.objects
            FOR SELECT TO authenticated
            USING (
                bucket_id = 'voice_notes' AND (
                    owner = auth.uid() OR
                    auth.uid() = (
                        SELECT vn.owner_id 
                        FROM public.voice_notes vn 
                        WHERE vn.id::text = REPLACE(storage.objects.name, '.m4a', '')
                    )
                )
            );

        -- Upload / Insert: somente usuários autenticados para seu próprio arquivo
        DROP POLICY IF EXISTS "voice_notes_storage_insert" ON storage.objects;
        CREATE POLICY "voice_notes_storage_insert" ON storage.objects
            FOR INSERT TO authenticated
            WITH CHECK (
                bucket_id = 'voice_notes' AND
                auth.role() = 'authenticated' AND
                (owner = auth.uid() OR owner IS NULL)
            );

        -- Atualização / Replace: somente o dono
        DROP POLICY IF EXISTS "voice_notes_storage_update" ON storage.objects;
        CREATE POLICY "voice_notes_storage_update" ON storage.objects
            FOR UPDATE TO authenticated
            USING (
                bucket_id = 'voice_notes' AND (
                    owner = auth.uid() OR
                    auth.uid() = (
                        SELECT vn.owner_id 
                        FROM public.voice_notes vn 
                        WHERE vn.id::text = REPLACE(storage.objects.name, '.m4a', '')
                    )
                )
            )
            WITH CHECK (
                bucket_id = 'voice_notes' AND (
                    owner = auth.uid() OR
                    auth.uid() = (
                        SELECT vn.owner_id 
                        FROM public.voice_notes vn 
                        WHERE vn.id::text = REPLACE(storage.objects.name, '.m4a', '')
                    )
                )
            );

        -- Exclusão / Delete: somente o dono
        DROP POLICY IF EXISTS "voice_notes_storage_delete" ON storage.objects;
        CREATE POLICY "voice_notes_storage_delete" ON storage.objects
            FOR DELETE TO authenticated
            USING (
                bucket_id = 'voice_notes' AND (
                    owner = auth.uid() OR
                    auth.uid() = (
                        SELECT vn.owner_id 
                        FROM public.voice_notes vn 
                        WHERE vn.id::text = REPLACE(storage.objects.name, '.m4a', '')
                    )
                )
            );
    END IF;
END $$;
