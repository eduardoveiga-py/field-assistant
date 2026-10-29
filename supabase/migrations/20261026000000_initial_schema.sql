-- ============================================================================
-- Supabase Schema Migration: Ministério Pessoal
-- Migration Version: 20261026000000_initial_schema.sql
-- Description: Tabelas completas com RLS, índices e suporte a sincronização
-- ============================================================================

-- Extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. TABELA: people (Contatos e Pessoas de Interesse)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.people (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    name TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    first_contact_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    status TEXT NOT NULL DEFAULT 'interessado' CHECK (status IN ('interessado', 'revisita', 'estudo', 'outro')),
    preferred_schedule TEXT,
    general_notes TEXT,
    contact_restrictions TEXT,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    last_contact_at TIMESTAMPTZ,
    next_action_at TIMESTAMPTZ,
    next_action_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);

-- Índices para People
CREATE INDEX IF NOT EXISTS idx_people_owner_id ON public.people(owner_id);
CREATE INDEX IF NOT EXISTS idx_people_status ON public.people(status);
CREATE INDEX IF NOT EXISTS idx_people_deleted_at ON public.people(deleted_at);
CREATE INDEX IF NOT EXISTS idx_people_last_contact ON public.people(last_contact_at);
CREATE INDEX IF NOT EXISTS idx_people_next_action ON public.people(next_action_at);

-- ----------------------------------------------------------------------------
-- 2. TABELA: visits (Visitas, Conversas e Retornos)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.visits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE CASCADE,
    date_time_field TIMESTAMPTZ NOT NULL,
    contact_type TEXT NOT NULL CHECK (contact_type IN (
        'conversa_inicial', 'revisita', 'estudo', 'tentativa_sem_contato', 'contato_telefonico', 'outro'
    )),
    result TEXT NOT NULL,
    notes TEXT,
    topics_discussed TEXT,
    scripture_or_pub TEXT,
    expressed_question TEXT,
    next_step TEXT,
    suggested_return_date TIMESTAMPTZ,
    appointment_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);

-- Índices para Visits
CREATE INDEX IF NOT EXISTS idx_visits_owner_id ON public.visits(owner_id);
CREATE INDEX IF NOT EXISTS idx_visits_person_id ON public.visits(person_id);
CREATE INDEX IF NOT EXISTS idx_visits_date_time ON public.visits(date_time_field);
CREATE INDEX IF NOT EXISTS idx_visits_contact_type ON public.visits(contact_type);
CREATE INDEX IF NOT EXISTS idx_visits_deleted_at ON public.visits(deleted_at);

-- ----------------------------------------------------------------------------
-- 3. TABELA: bible_studies (Estudos Bíblicos)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bible_studies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    title TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    status TEXT NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo', 'pausado', 'concluido', 'encerrado')),
    publication_id TEXT NOT NULL,
    language TEXT NOT NULL DEFAULT 'pt',
    current_lesson INTEGER,
    current_paragraph INTEGER,
    manual_reference TEXT,
    frequency TEXT NOT NULL DEFAULT 'semanal' CHECK (frequency IN ('semanal', 'quinzenal', 'mensal', 'personalizada')),
    learning_goals TEXT,
    pending_doubts TEXT,
    next_topic TEXT,
    pause_or_close_reason TEXT,
    last_session_at TIMESTAMPTZ,
    next_planned_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);

-- Índices para Bible Studies
CREATE INDEX IF NOT EXISTS idx_studies_owner_id ON public.bible_studies(owner_id);
CREATE INDEX IF NOT EXISTS idx_studies_status ON public.bible_studies(status);
CREATE INDEX IF NOT EXISTS idx_studies_deleted_at ON public.bible_studies(deleted_at);
CREATE INDEX IF NOT EXISTS idx_studies_next_planned ON public.bible_studies(next_planned_at);

-- ----------------------------------------------------------------------------
-- 4. TABELA: study_participants (Estudantes Vinculados ao Estudo)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.study_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    study_id UUID NOT NULL REFERENCES public.bible_studies(id) ON DELETE CASCADE,
    person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE CASCADE,
    is_primary BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT uq_study_person UNIQUE (study_id, person_id)
);

-- Índices para Study Participants
CREATE INDEX IF NOT EXISTS idx_participants_study_id ON public.study_participants(study_id);
CREATE INDEX IF NOT EXISTS idx_participants_person_id ON public.study_participants(person_id);
CREATE INDEX IF NOT EXISTS idx_participants_deleted_at ON public.study_participants(deleted_at);

-- ----------------------------------------------------------------------------
-- 5. TABELA: study_sessions (Sessões / Aulas Realizadas)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.study_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    study_id UUID NOT NULL REFERENCES public.bible_studies(id) ON DELETE CASCADE,
    date_time_field TIMESTAMPTZ NOT NULL,
    publication_code TEXT,
    lesson_covered INTEGER,
    paragraphs_covered TEXT,
    session_notes TEXT,
    pending_questions TEXT,
    next_step TEXT,
    status TEXT NOT NULL DEFAULT 'realizada' CHECK (status IN ('realizada', 'cancelada', 'nao_realizada')),
    participant_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);

-- Índices para Study Sessions
CREATE INDEX IF NOT EXISTS idx_sessions_study_id ON public.study_sessions(study_id);
CREATE INDEX IF NOT EXISTS idx_sessions_date_time ON public.study_sessions(date_time_field);
CREATE INDEX IF NOT EXISTS idx_sessions_deleted_at ON public.study_sessions(deleted_at);

-- ----------------------------------------------------------------------------
-- 6. TABELA: appointments (Compromissos e Agendamentos da Agenda)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    person_id UUID REFERENCES public.people(id) ON DELETE SET NULL,
    study_id UUID REFERENCES public.bible_studies(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    duration_minutes INTEGER NOT NULL DEFAULT 30,
    status TEXT NOT NULL DEFAULT 'planejado' CHECK (status IN (
        'planejado', 'confirmado', 'realizado', 'cancelado', 'nao_realizado', 'reagendado', 'provisorio'
    )),
    previous_appointment_id UUID REFERENCES public.appointments(id) ON DELETE SET NULL,
    location_notes TEXT,
    reminder_minutes_before INTEGER,
    second_reminder_minutes_before INTEGER,
    is_provisional BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);

-- Índices para Appointments
CREATE INDEX IF NOT EXISTS idx_appointments_owner_id ON public.appointments(owner_id);
CREATE INDEX IF NOT EXISTS idx_appointments_start_time ON public.appointments(start_time);
CREATE INDEX IF NOT EXISTS idx_appointments_end_time ON public.appointments(end_time);
CREATE INDEX IF NOT EXISTS idx_appointments_person_id ON public.appointments(person_id);
CREATE INDEX IF NOT EXISTS idx_appointments_study_id ON public.appointments(study_id);
CREATE INDEX IF NOT EXISTS idx_appointments_deleted_at ON public.appointments(deleted_at);
CREATE INDEX IF NOT EXISTS idx_appointments_status ON public.appointments(status);

-- ----------------------------------------------------------------------------
-- 7. TABELA: activity_records (Horas, Publicações e Atividades de Campo)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.activity_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    date TIMESTAMPTZ NOT NULL,
    duration_seconds INTEGER NOT NULL,
    modality TEXT NOT NULL CHECK (modality IN ('campo', 'testemunho_publico', 'informal', 'carta_telefone', 'outro')),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    deleted_at TIMESTAMPTZ,
    revision INTEGER NOT NULL DEFAULT 1
);

-- Índices para Activity Records
CREATE INDEX IF NOT EXISTS idx_activities_owner_id ON public.activity_records(owner_id);
CREATE INDEX IF NOT EXISTS idx_activities_date ON public.activity_records(date);
CREATE INDEX IF NOT EXISTS idx_activities_deleted_at ON public.activity_records(deleted_at);

-- ----------------------------------------------------------------------------
-- 8. TABELA: sync_queue (Fila de Sincronização e Idempotência)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sync_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    operation TEXT NOT NULL CHECK (operation IN ('insert', 'update', 'delete', 'INSERT', 'UPDATE', 'DELETE')),
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    attempts INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'synced', 'conflict', 'failed'))
);

CREATE INDEX IF NOT EXISTS idx_sync_queue_owner_status ON public.sync_queue(owner_id, status);

-- ----------------------------------------------------------------------------
-- 9. ROW-LEVEL SECURITY (RLS) POLICIES
-- ----------------------------------------------------------------------------
ALTER TABLE public.people ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bible_studies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_queue ENABLE ROW LEVEL SECURITY;

-- Políticas de Isolamento por Usuário (auth.uid() = owner_id)
DO $$
DECLARE
    tbl text;
    tables text[] := ARRAY[
        'people', 'visits', 'bible_studies', 'study_participants', 
        'study_sessions', 'appointments', 'activity_records', 'sync_queue'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I_user_policy ON public.%I', tbl, tbl);
        EXECUTE format('
            CREATE POLICY %I_user_policy ON public.%I
            FOR ALL
            TO authenticated
            USING (auth.uid() = owner_id)
            WITH CHECK (auth.uid() = owner_id)
        ', tbl, tbl);
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 10. TRIGGER PARA ATUALIZAÇÃO AUTOMÁTICA DE updated_at E revision
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_update_audit()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    IF TG_TABLE_NAME != 'sync_queue' THEN
        NEW.revision = OLD.revision + 1;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
    tbl text;
    tables text[] := ARRAY[
        'people', 'visits', 'bible_studies', 'study_participants', 
        'study_sessions', 'appointments', 'activity_records'
    ];
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
