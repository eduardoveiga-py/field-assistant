-- ==============================================================================
-- MIGRAÇÃO ESTRATÉGICA: INBOX UNIVERSAL + TAREFAS/PROJETOS + BASE DE CONHECIMENTO
-- Versão: 20261110000000
-- ==============================================================================

-- 1. Tabela base research_articles (caso ainda não tenha sido criada) e colunas adicionais
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
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);

ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS task_id TEXT;
ALTER TABLE public.research_articles ADD COLUMN IF NOT EXISTS objective TEXT;
ALTER TABLE public.research_articles ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';
ALTER TABLE public.research_articles ADD COLUMN IF NOT EXISTS conclusion TEXT;
ALTER TABLE public.research_articles ADD COLUMN IF NOT EXISTS project_id TEXT;
ALTER TABLE public.research_articles ADD COLUMN IF NOT EXISTS main_question_id TEXT;

-- 2. Módulo A — Inbox Universal
CREATE TABLE IF NOT EXISTS public.inbox_entries (
    id TEXT PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    content TEXT NOT NULL,
    source_type TEXT NOT NULL DEFAULT 'text',
    media_path TEXT,
    media_duration_seconds INTEGER,
    attachments JSONB NOT NULL DEFAULT '[]'::jsonb,
    status TEXT NOT NULL DEFAULT 'unprocessed',
    suggested_category TEXT,
    converted_entity_type TEXT,
    converted_entity_id TEXT,
    captured_at TIMESTAMPTZ NOT NULL,
    processed_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);

ALTER TABLE public.inbox_entries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own inbox_entries" ON public.inbox_entries;
CREATE POLICY "Users can manage their own inbox_entries"
    ON public.inbox_entries FOR ALL
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

CREATE INDEX IF NOT EXISTS idx_inbox_entries_owner_status ON public.inbox_entries (owner_id, status);

-- 3. Módulo B — Projetos
CREATE TABLE IF NOT EXISTS public.projects (
    id TEXT PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    name TEXT NOT NULL,
    objective TEXT,
    description TEXT,
    category TEXT NOT NULL DEFAULT 'ministry',
    status TEXT NOT NULL DEFAULT 'active',
    color_hex TEXT,
    icon_name TEXT,
    start_date TIMESTAMPTZ,
    target_date TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    origin_inbox_id TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);

ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own projects" ON public.projects;
CREATE POLICY "Users can manage their own projects"
    ON public.projects FOR ALL
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

CREATE INDEX IF NOT EXISTS idx_projects_owner_status ON public.projects (owner_id, status);

-- 4. Módulo B — Tarefas
CREATE TABLE IF NOT EXISTS public.tasks (
    id TEXT PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    project_id TEXT,
    person_id TEXT,
    study_id TEXT,
    sector_id TEXT,
    origin_inbox_id TEXT,
    parent_task_id TEXT,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'todo',
    priority TEXT NOT NULL DEFAULT 'normal',
    category TEXT NOT NULL DEFAULT 'ministry',
    start_date TIMESTAMPTZ,
    due_date TIMESTAMPTZ,
    scheduled_at TIMESTAMPTZ,
    duration_minutes INTEGER DEFAULT 30,
    completed_at TIMESTAMPTZ,
    is_recurring BOOLEAN NOT NULL DEFAULT false,
    recurrence_rule TEXT,
    appointment_id TEXT,
    attachments JSONB NOT NULL DEFAULT '[]'::jsonb,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own tasks" ON public.tasks;
CREATE POLICY "Users can manage their own tasks"
    ON public.tasks FOR ALL
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

CREATE INDEX IF NOT EXISTS idx_tasks_owner_status ON public.tasks (owner_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_owner_project ON public.tasks (owner_id, project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_owner_person ON public.tasks (owner_id, person_id);
CREATE INDEX IF NOT EXISTS idx_tasks_owner_due_date ON public.tasks (owner_id, due_date);

-- 5. Módulo C — Base de Conhecimento: Notas
CREATE TABLE IF NOT EXISTS public.knowledge_notes (
    id TEXT PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    project_id TEXT,
    person_id TEXT,
    study_id TEXT,
    origin_inbox_id TEXT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'general',
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    attachments JSONB NOT NULL DEFAULT '[]'::jsonb,
    sources JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);

ALTER TABLE public.knowledge_notes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own knowledge_notes" ON public.knowledge_notes;
CREATE POLICY "Users can manage their own knowledge_notes"
    ON public.knowledge_notes FOR ALL
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_notes_owner ON public.knowledge_notes (owner_id, is_pinned);

-- 6. Módulo C — Base de Conhecimento: Perguntas
CREATE TABLE IF NOT EXISTS public.knowledge_questions (
    id TEXT PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    project_id TEXT,
    person_id TEXT,
    study_id TEXT,
    origin_inbox_id TEXT,
    research_article_id TEXT,
    question TEXT NOT NULL,
    context TEXT,
    category TEXT NOT NULL DEFAULT 'biblical',
    status TEXT NOT NULL DEFAULT 'unanswered',
    answer TEXT,
    answered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);

ALTER TABLE public.knowledge_questions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own knowledge_questions" ON public.knowledge_questions;
CREATE POLICY "Users can manage their own knowledge_questions"
    ON public.knowledge_questions FOR ALL
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_questions_owner_status ON public.knowledge_questions (owner_id, status);

-- 7. Módulo C — Base de Conhecimento: Documentos
CREATE TABLE IF NOT EXISTS public.knowledge_documents (
    id TEXT PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    project_id TEXT,
    research_article_id TEXT,
    person_id TEXT,
    sector_id TEXT,
    origin_inbox_id TEXT,
    title TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_type TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    file_path TEXT NOT NULL,
    remote_storage_path TEXT,
    sha256_checksum TEXT,
    description TEXT,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    category TEXT NOT NULL DEFAULT 'general',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);

ALTER TABLE public.knowledge_documents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own knowledge_documents" ON public.knowledge_documents;
CREATE POLICY "Users can manage their own knowledge_documents"
    ON public.knowledge_documents FOR ALL
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_documents_owner ON public.knowledge_documents (owner_id);

-- 8. Módulo C — Base de Conhecimento: Recursos
CREATE TABLE IF NOT EXISTS public.knowledge_resources (
    id TEXT PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    project_id TEXT,
    research_article_id TEXT,
    person_id TEXT,
    origin_inbox_id TEXT,
    title TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    description TEXT,
    url TEXT,
    local_asset_path TEXT,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    category TEXT NOT NULL DEFAULT 'general',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);

ALTER TABLE public.knowledge_resources ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own knowledge_resources" ON public.knowledge_resources;
CREATE POLICY "Users can manage their own knowledge_resources"
    ON public.knowledge_resources FOR ALL
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_resources_owner ON public.knowledge_resources (owner_id);

-- 9. Storage: Bucket Privado knowledge_vault
INSERT INTO storage.buckets (id, name, public)
VALUES ('knowledge_vault', 'knowledge_vault', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Users can access their own knowledge_vault storage objects" ON storage.objects;
CREATE POLICY "Users can access their own knowledge_vault storage objects"
    ON storage.objects
    FOR ALL
    USING (bucket_id = 'knowledge_vault' AND auth.uid() = (storage.foldername(name))[1]::uuid)
    WITH CHECK (bucket_id = 'knowledge_vault' AND auth.uid() = (storage.foldername(name))[1]::uuid);
