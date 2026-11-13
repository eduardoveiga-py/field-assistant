-- ==============================================================================
-- MIGRAÇÃO DE ALINHAMENTO INTEGRAL DE SCHEMA: 26 TABELAS DE SINCRONIZAÇÃO + RPC
-- Versão: 20261111000000
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. ALINHAMENTO DE COLUNAS EM TABELAS EXISTENTES
-- ------------------------------------------------------------------------------

-- 1.1 sync_queue: suporte a registro de última tentativa de backoff (C1)
ALTER TABLE public.sync_queue
    ADD COLUMN IF NOT EXISTS last_attempt_at TIMESTAMPTZ;

-- 1.2 voice_notes: alinhamento exato com lib/database/tables.dart (VoiceNotes)
ALTER TABLE public.voice_notes
    ALTER COLUMN owner_id SET DEFAULT auth.uid(),
    ADD COLUMN IF NOT EXISTS person_id UUID REFERENCES public.people(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS visit_id UUID REFERENCES public.visits(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS study_id UUID REFERENCES public.bible_studies(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS audio_file_path TEXT,
    ADD COLUMN IF NOT EXISTS audio_duration_seconds INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS transcription TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS detected_lesson INTEGER,
    ADD COLUMN IF NOT EXISTS detected_point INTEGER,
    ADD COLUMN IF NOT EXISTS extracted_pending_doubt TEXT,
    ADD COLUMN IF NOT EXISTS extracted_empathy_note TEXT,
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS revision INTEGER NOT NULL DEFAULT 1;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'voice_notes' AND column_name = 'duration'
    ) THEN
        EXECUTE 'UPDATE public.voice_notes SET audio_duration_seconds = COALESCE(duration, 0) WHERE audio_duration_seconds = 0 AND duration IS NOT NULL';
    END IF;
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'voice_notes' AND column_name = 'audio_path'
    ) THEN
        EXECUTE 'UPDATE public.voice_notes SET audio_file_path = audio_path WHERE audio_file_path IS NULL AND audio_path IS NOT NULL';
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_voice_notes_owner_person ON public.voice_notes(owner_id, person_id);
CREATE INDEX IF NOT EXISTS idx_voice_notes_deleted_at ON public.voice_notes(deleted_at);

-- 1.3 phone_contacts: alinhamento exato com lib/database/tables.dart (PhoneContacts)
ALTER TABLE public.phone_contacts
    ALTER COLUMN owner_id SET DEFAULT auth.uid(),
    ADD COLUMN IF NOT EXISTS phone TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS secondary_phone TEXT,
    ADD COLUMN IF NOT EXISTS has_whatsapp BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS whatsapp_info TEXT,
    ADD COLUMN IF NOT EXISTS has_social BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS social_platform TEXT,
    ADD COLUMN IF NOT EXISTS social_handle TEXT,
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS origin TEXT NOT NULL DEFAULT 'Informal',
    ADD COLUMN IF NOT EXISTS converted_person_id UUID REFERENCES public.people(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS revision INTEGER NOT NULL DEFAULT 1;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'phone_contacts' AND column_name = 'phone_number'
    ) THEN
        EXECUTE 'UPDATE public.phone_contacts SET phone = COALESCE(phone_number, '''') WHERE phone = '''' AND phone_number IS NOT NULL';
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_phone_contacts_owner ON public.phone_contacts(owner_id);
CREATE INDEX IF NOT EXISTS idx_phone_contacts_deleted_at ON public.phone_contacts(deleted_at);

-- 1.4 territory_landmarks: alinhamento exato com lib/database/tables.dart (TerritoryLandmarks)
ALTER TABLE public.territory_landmarks
    ALTER COLUMN owner_id SET DEFAULT auth.uid(),
    ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'outro',
    ADD COLUMN IF NOT EXISTS address TEXT,
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS revision INTEGER NOT NULL DEFAULT 1;

CREATE INDEX IF NOT EXISTS idx_territory_landmarks_owner ON public.territory_landmarks(owner_id);
CREATE INDEX IF NOT EXISTS idx_territory_landmarks_deleted_at ON public.territory_landmarks(deleted_at);

-- ------------------------------------------------------------------------------
-- 2. CRIAÇÃO DAS 9 TABELAS FALTANTES DE SINCRONIZAÇÃO
-- ------------------------------------------------------------------------------

-- 2.1 family_ties
CREATE TABLE IF NOT EXISTS public.family_ties (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE CASCADE,
    related_person_id UUID REFERENCES public.people(id) ON DELETE SET NULL,
    related_person_name TEXT NOT NULL,
    relationship_type TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_family_ties_owner_person ON public.family_ties(owner_id, person_id);
CREATE INDEX IF NOT EXISTS idx_family_ties_deleted_at ON public.family_ties(deleted_at);

-- 2.2 ministry_experiences
CREATE TABLE IF NOT EXISTS public.ministry_experiences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    media_urls JSONB NOT NULL DEFAULT '[]'::jsonb,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    date_time_field TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    location_or_modality TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_ministry_experiences_owner ON public.ministry_experiences(owner_id, date_time_field);
CREATE INDEX IF NOT EXISTS idx_ministry_experiences_deleted_at ON public.ministry_experiences(deleted_at);

-- 2.3 person_photos (inclui file_path para migração de fotos base64 A3 -> Storage)
CREATE TABLE IF NOT EXISTS public.person_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE CASCADE,
    photo_type TEXT NOT NULL DEFAULT 'person',
    image_data TEXT NOT NULL DEFAULT '',
    file_path TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_person_photos_owner_person ON public.person_photos(owner_id, person_id);
CREATE INDEX IF NOT EXISTS idx_person_photos_deleted_at ON public.person_photos(deleted_at);

-- 2.4 person_publications
CREATE TABLE IF NOT EXISTS public.person_publications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE CASCADE,
    publication_title TEXT NOT NULL,
    item_type TEXT NOT NULL,
    status TEXT NOT NULL,
    date TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_person_publications_owner_person ON public.person_publications(owner_id, person_id);
CREATE INDEX IF NOT EXISTS idx_person_publications_deleted_at ON public.person_publications(deleted_at);

-- 2.5 research_articles (garante existência + índices + RLS)
CREATE TABLE IF NOT EXISTS public.research_articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    title TEXT NOT NULL,
    summary TEXT NOT NULL DEFAULT '',
    content TEXT NOT NULL DEFAULT '',
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    attachments JSONB NOT NULL DEFAULT '[]'::jsonb,
    objective TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    conclusion TEXT,
    project_id TEXT,
    main_question_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);
ALTER TABLE public.research_articles
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS revision INTEGER NOT NULL DEFAULT 1;
CREATE INDEX IF NOT EXISTS idx_research_articles_owner ON public.research_articles(owner_id);
CREATE INDEX IF NOT EXISTS idx_research_articles_deleted_at ON public.research_articles(deleted_at);

-- 2.6 research_tags
CREATE TABLE IF NOT EXISTS public.research_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_research_tags_owner ON public.research_tags(owner_id);
CREATE INDEX IF NOT EXISTS idx_research_tags_deleted_at ON public.research_tags(deleted_at);

-- 2.7 territory_sectors
CREATE TABLE IF NOT EXISTS public.territory_sectors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_territory_sectors_owner ON public.territory_sectors(owner_id);
CREATE INDEX IF NOT EXISTS idx_territory_sectors_deleted_at ON public.territory_sectors(deleted_at);

-- 2.8 ticuna_words (chave TEXT para suportar IDs canônicos/migrados além de UUID)
CREATE TABLE IF NOT EXISTS public.ticuna_words (
    id TEXT PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    word TEXT NOT NULL,
    translation TEXT NOT NULL,
    phonetics TEXT,
    grammatical_class TEXT,
    example_sentence TEXT,
    example_translation TEXT,
    notes TEXT,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_favorite INTEGER NOT NULL DEFAULT 0,
    review_level INTEGER NOT NULL DEFAULT 0,
    review_count INTEGER NOT NULL DEFAULT 0,
    last_reviewed_at TEXT,
    audio_path TEXT,
    audio_duration_seconds INTEGER,
    language_id TEXT DEFAULT 'tca',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_ticuna_words_owner ON public.ticuna_words(owner_id);
CREATE INDEX IF NOT EXISTS idx_ticuna_words_deleted_at ON public.ticuna_words(deleted_at);

-- 2.9 ticuna_phrases
CREATE TABLE IF NOT EXISTS public.ticuna_phrases (
    id TEXT PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    phrase TEXT NOT NULL,
    translation TEXT NOT NULL,
    category TEXT,
    phonetics TEXT,
    notes TEXT,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_favorite INTEGER NOT NULL DEFAULT 0,
    audio_path TEXT,
    audio_duration_seconds INTEGER,
    language_id TEXT DEFAULT 'tca',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_ticuna_phrases_owner ON public.ticuna_phrases(owner_id);
CREATE INDEX IF NOT EXISTS idx_ticuna_phrases_deleted_at ON public.ticuna_phrases(deleted_at);

-- ------------------------------------------------------------------------------
-- 3. RLS + TRIGGER DE AUDITORIA EM TODAS AS 26 TABELAS
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_update_audit()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = COALESCE(NEW.updated_at, timezone('utc'::text, now()));
    IF TG_TABLE_NAME != 'sync_queue' THEN
        IF COALESCE(NEW.revision, 1) = COALESCE(OLD.revision, 1)
           AND date_trunc('milliseconds', NEW.updated_at) IS NOT DISTINCT FROM date_trunc('milliseconds', OLD.updated_at) THEN
            NEW.revision = OLD.revision;
        ELSE
            NEW.revision = GREATEST(COALESCE(OLD.revision, 0) + 1, COALESCE(NEW.revision, 1));
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

DO $$
DECLARE
    tbl text;
    all_tables text[] := ARRAY[
        'voice_notes', 'phone_contacts', 'territory_landmarks',
        'family_ties', 'ministry_experiences', 'person_photos',
        'person_publications', 'research_articles', 'research_tags',
        'territory_sectors', 'ticuna_words', 'ticuna_phrases',
        'inbox_entries', 'projects', 'tasks', 'knowledge_notes',
        'knowledge_questions', 'knowledge_documents', 'knowledge_resources'
    ];
BEGIN
    FOREACH tbl IN ARRAY all_tables LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', tbl);
        EXECUTE format('DROP POLICY IF EXISTS %I_user_policy ON public.%I', tbl, tbl);
        EXECUTE format('
            CREATE POLICY %I_user_policy ON public.%I
            FOR ALL
            TO authenticated
            USING ((select auth.uid()) = owner_id)
            WITH CHECK ((select auth.uid()) = owner_id)
        ', tbl, tbl);

        EXECUTE format('DROP TRIGGER IF EXISTS trigger_%I_audit ON public.%I', tbl, tbl);
        EXECUTE format('
            CREATE TRIGGER trigger_%I_audit
            BEFORE UPDATE ON public.%I
            FOR EACH ROW
            EXECUTE FUNCTION public.handle_update_audit();
        ', tbl, tbl);
    END LOOP;
END $$;

-- ------------------------------------------------------------------------------
-- 4. STORAGE: BUCKET PRIVADO person_photos + REFORÇO DE POLÍTICAS
-- ------------------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public)
VALUES ('person_photos', 'person_photos', false)
ON CONFLICT (id) DO NOTHING;

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

-- ------------------------------------------------------------------------------
-- 5. RPC SERVER-SIDE PARA TRAVA OTIMISTA ATÔMICA (C2 / M5)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.sync_upsert(
    p_table TEXT,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_allowed_tables CONSTANT TEXT[] := ARRAY[
        'people', 'visits', 'bible_studies', 'study_participants',
        'study_sessions', 'appointments', 'activity_records',
        'voice_notes', 'phone_contacts', 'territory_landmarks',
        'family_ties', 'ministry_experiences', 'person_photos',
        'person_publications', 'research_articles', 'research_tags',
        'territory_sectors', 'inbox_entries', 'projects', 'tasks',
        'knowledge_notes', 'knowledge_questions', 'knowledge_documents',
        'knowledge_resources', 'ticuna_words', 'ticuna_phrases'
    ];
    v_id TEXT;
    v_incoming_rev INTEGER;
    v_existing JSONB;
    v_existing_rev INTEGER;
    v_existing_owner UUID;
    v_sanitized JSONB;
    v_cols TEXT;
    v_vals TEXT;
    v_updates TEXT;
    v_affected INTEGER := 0;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Autenticação obrigatória para sync_upsert.' USING ERRCODE = '42501';
    END IF;

    IF NOT (p_table = ANY(v_allowed_tables)) THEN
        RAISE EXCEPTION 'Tabela não permitida em sync_upsert: %', p_table USING ERRCODE = '42501';
    END IF;

    v_id := p_payload->>'id';
    IF v_id IS NULL OR length(trim(v_id)) = 0 THEN
        RAISE EXCEPTION 'Payload de sync_upsert deve conter id válido.' USING ERRCODE = '22023';
    END IF;

    v_incoming_rev := GREATEST(1, COALESCE((p_payload->>'revision')::INTEGER, 1));
    v_sanitized := p_payload || jsonb_build_object('owner_id', v_uid::TEXT);

    -- Verifica se já existe registro remoto e se pertence ao usuário autenticado
    EXECUTE format(
        'SELECT to_jsonb(t), t.revision, t.owner_id FROM public.%I t WHERE t.id::text = $1 LIMIT 1',
        p_table
    )
    INTO v_existing, v_existing_rev, v_existing_owner
    USING v_id;

    IF v_existing IS NOT NULL THEN
        IF v_existing_owner IS DISTINCT FROM v_uid THEN
            RAISE EXCEPTION 'Acesso negado ao registro % em %', v_id, p_table USING ERRCODE = '42501';
        END IF;

        -- Trava otimista: rejeita sobrescrita caso revisão remota seja >= à revisão enviada
        -- (exceto retry idempotente exato com mesmo updated_at e mesma revisão)
        IF v_existing_rev > v_incoming_rev
           OR (
               v_existing_rev = v_incoming_rev
               AND date_trunc('milliseconds', NULLIF(v_existing->>'updated_at', '')::timestamptz)
                   IS DISTINCT FROM date_trunc('milliseconds', NULLIF(p_payload->>'updated_at', '')::timestamptz)
           ) THEN
            RETURN jsonb_build_object(
                'success', false,
                'conflict', true,
                'code', '23505',
                'message', format(
                    'Optimistic lock conflict on %s (%s): remote revision=%s, incoming=%s',
                    p_table, v_id, v_existing_rev, v_incoming_rev
                ),
                'server_revision', v_existing_rev,
                'server_record', v_existing
            );
        END IF;
    END IF;

    -- Monta INSERT/ON CONFLICT dinâmico apenas para colunas reais da tabela e presentes no payload
    SELECT
        string_agg(format('%I', c.column_name), ', '),
        string_agg(format('r.%I', c.column_name), ', '),
        string_agg(format('%I = EXCLUDED.%I', c.column_name, c.column_name), ', ')
    INTO v_cols, v_vals, v_updates
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = p_table
      AND v_sanitized ? c.column_name;

    EXECUTE format(
        $sql$WITH payload_row AS (
             SELECT * FROM jsonb_populate_record(NULL::public.%I, $1)
         )
         INSERT INTO public.%I (%s)
         SELECT %s FROM payload_row r
         ON CONFLICT (id) DO UPDATE
         SET %s
         WHERE public.%I.owner_id = $2
           AND (
               public.%I.revision < $3
               OR (
                   public.%I.revision = $3
                   AND date_trunc('milliseconds', public.%I.updated_at)
                       IS NOT DISTINCT FROM date_trunc('milliseconds', NULLIF($4, '')::timestamptz)
               )
           )$sql$,
        p_table, p_table, v_cols, v_vals, v_updates,
        p_table, p_table, p_table, p_table
    )
    USING v_sanitized, v_uid, v_incoming_rev, (p_payload->>'updated_at');

    GET DIAGNOSTICS v_affected = ROW_COUNT;

    IF v_affected = 0 THEN
        -- Corrida concorrente detectada atomicamente no momento do COMMIT
        EXECUTE format(
            'SELECT to_jsonb(t), t.revision FROM public.%I t WHERE t.id::text = $1 AND t.owner_id = $2 LIMIT 1',
            p_table
        )
        INTO v_existing, v_existing_rev
        USING v_id, v_uid;

        RETURN jsonb_build_object(
            'success', false,
            'conflict', true,
            'code', '23505',
            'message', format(
                'Concurrent optimistic lock conflict on %s (%s): remote revision=%s',
                p_table, v_id, COALESCE(v_existing_rev, -1)
            ),
            'server_revision', COALESCE(v_existing_rev, -1),
            'server_record', v_existing
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'conflict', false,
        'processed_count', 1,
        'table', p_table,
        'id', v_id,
        'revision', v_incoming_rev
    );
END;
$$;

REVOKE ALL ON FUNCTION public.sync_upsert(TEXT, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sync_upsert(TEXT, JSONB) TO authenticated;
