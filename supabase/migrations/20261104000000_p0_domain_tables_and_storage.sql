-- ============================================================================
-- Supabase Schema Migration: Ministério Pessoal — P0 Domain Tables & Storage
-- Migration Version: 20261104000000_p0_domain_tables_and_storage.sql
-- Description: Implementação remota das 8 tabelas de domínio restantes:
--              family_ties, ministry_experiences, person_photos,
--              person_publications, research_articles, research_tags,
--              territory_sectors, student_manual_order.
--              Contratos estritos de RLS por owner_id = auth.uid(),
--              prevenção de ressurreição (tombstones) e checks de ownership.
-- ============================================================================

-- 1. FAMILY TIES (Vínculos Familiares)
CREATE TABLE IF NOT EXISTS public.family_ties (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE CASCADE,
    related_person_id UUID REFERENCES public.people(id) ON DELETE SET NULL,
    related_person_name TEXT NOT NULL,
    relationship_type TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    revision INT NOT NULL DEFAULT 1
);

ALTER TABLE public.family_ties ENABLE ROW LEVEL SECURITY;

CREATE POLICY "family_ties_owner_isolation" ON public.family_ties
    FOR ALL TO authenticated
    USING (owner_id = auth.uid())
    WITH CHECK (
        owner_id = auth.uid() AND
        EXISTS (SELECT 1 FROM public.people p WHERE p.id = person_id AND p.owner_id = auth.uid())
    );

-- 2. MINISTRY EXPERIENCES (Experiências de Campo)
CREATE TABLE IF NOT EXISTS public.ministry_experiences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    media_urls JSONB NOT NULL DEFAULT '[]'::jsonb,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    date_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    location_or_modality TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    revision INT NOT NULL DEFAULT 1
);

ALTER TABLE public.ministry_experiences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ministry_experiences_owner_isolation" ON public.ministry_experiences
    FOR ALL TO authenticated
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

-- 3. PERSON PHOTOS (Fotos de Perfil e Documentos)
CREATE TABLE IF NOT EXISTS public.person_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE CASCADE,
    photo_type TEXT NOT NULL,
    image_data TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    revision INT NOT NULL DEFAULT 1
);

ALTER TABLE public.person_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "person_photos_owner_isolation" ON public.person_photos
    FOR ALL TO authenticated
    USING (owner_id = auth.uid())
    WITH CHECK (
        owner_id = auth.uid() AND
        EXISTS (SELECT 1 FROM public.people p WHERE p.id = person_id AND p.owner_id = auth.uid())
    );

-- 4. PERSON PUBLICATIONS (Literatura Deixada e Histórico)
CREATE TABLE IF NOT EXISTS public.person_publications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE CASCADE,
    publication_title TEXT NOT NULL,
    item_type TEXT NOT NULL,
    status TEXT NOT NULL,
    date TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    revision INT NOT NULL DEFAULT 1
);

ALTER TABLE public.person_publications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "person_publications_owner_isolation" ON public.person_publications
    FOR ALL TO authenticated
    USING (owner_id = auth.uid())
    WITH CHECK (
        owner_id = auth.uid() AND
        EXISTS (SELECT 1 FROM public.people p WHERE p.id = person_id AND p.owner_id = auth.uid())
    );

-- 5. RESEARCH ARTICLES (Notas de Pesquisa Pastoral)
CREATE TABLE IF NOT EXISTS public.research_articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    summary TEXT NOT NULL,
    content TEXT NOT NULL,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    attachments JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    revision INT NOT NULL DEFAULT 1
);

ALTER TABLE public.research_articles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "research_articles_owner_isolation" ON public.research_articles
    FOR ALL TO authenticated
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

-- 6. RESEARCH TAGS (Etiquetas de Indexação)
CREATE TABLE IF NOT EXISTS public.research_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    revision INT NOT NULL DEFAULT 1
);

ALTER TABLE public.research_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "research_tags_owner_isolation" ON public.research_tags
    FOR ALL TO authenticated
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

-- 7. TERRITORY SECTORS (Setores Territoriais de Apoio)
CREATE TABLE IF NOT EXISTS public.territory_sectors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    revision INT NOT NULL DEFAULT 1
);

ALTER TABLE public.territory_sectors ENABLE ROW LEVEL SECURITY;

CREATE POLICY "territory_sectors_owner_isolation" ON public.territory_sectors
    FOR ALL TO authenticated
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

-- 8. STUDENT MANUAL ORDER (Ordenação de Estudantes)
CREATE TABLE IF NOT EXISTS public.student_manual_order (
    study_id UUID PRIMARY KEY REFERENCES public.bible_studies(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    manual_index INT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    revision INT NOT NULL DEFAULT 1
);

ALTER TABLE public.student_manual_order ENABLE ROW LEVEL SECURITY;

CREATE POLICY "student_manual_order_owner_isolation" ON public.student_manual_order
    FOR ALL TO authenticated
    USING (owner_id = auth.uid())
    WITH CHECK (
        owner_id = auth.uid() AND
        EXISTS (SELECT 1 FROM public.bible_studies s WHERE s.id = study_id AND s.owner_id = auth.uid())
    );

-- ----------------------------------------------------------------------------
-- TRIGGERS DE AUDITORIA E PREVENÇÃO DE RESSURREIÇÃO PARA AS NOVAS TABELAS
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN SELECT unnest(ARRAY[
        'family_ties',
        'ministry_experiences',
        'person_photos',
        'person_publications',
        'research_articles',
        'research_tags',
        'territory_sectors',
        'student_manual_order'
    ]) LOOP
        EXECUTE format('
            DROP TRIGGER IF EXISTS trg_audit_%I ON public.%I;
            CREATE TRIGGER trg_audit_%I
                BEFORE UPDATE ON public.%I
                FOR EACH ROW
                EXECUTE FUNCTION public.handle_update_audit();
        ', tbl, tbl, tbl, tbl);

        EXECUTE format('
            DROP TRIGGER IF EXISTS trg_prevent_resurrection_%I ON public.%I;
            CREATE TRIGGER trg_prevent_resurrection_%I
                BEFORE UPDATE ON public.%I
                FOR EACH ROW
                EXECUTE FUNCTION public.prevent_stale_resurrection();
        ', tbl, tbl, tbl, tbl);
    END LOOP;
END;
$$;
