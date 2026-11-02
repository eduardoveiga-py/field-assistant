-- ============================================================================
-- Supabase Schema Migration: Ministério Pessoal — Unidade U3.1
-- Migration Version: 20261102010000_u3_1_soft_delete_tombstones.sql
-- Description: Preservação de tombstones no servidor Supabase/PostgreSQL,
--              proteção contra ressurreição por upserts desatualizados
--              e sincronização de exclusões lógicas (U3.1).
-- ============================================================================

-- Função trigger para proteção de tombstones e garantia de integridade em atualizações
CREATE OR REPLACE FUNCTION public.handle_soft_delete_and_resurrection_guard()
RETURNS TRIGGER AS $$
BEGIN
    -- 1. Se o registro já era um tombstone (deleted_at já preenchido no servidor)
    IF OLD.deleted_at IS NOT NULL THEN
        -- Se a mutação recebida tenta limpar deleted_at (ressuscitar o registro)
        IF NEW.deleted_at IS NULL THEN
            -- Proteção contra ressurreição:
            -- Se a operação recebida for mais antiga, concorrente ou não comprovar restauração legítima
            -- (updated_at <= OLD.deleted_at ou updated_at IS NULL ou revision <= OLD.revision ou revision IS NULL),
            -- PRESERVA O TOMBSTONE no servidor.
            -- Somente aceita restauração se for uma ação explícita com revision > OLD.revision
            -- E updated_at posterior a OLD.deleted_at.
            IF (NEW.updated_at IS NULL OR NEW.updated_at <= OLD.deleted_at) OR
               (COALESCE(NEW.revision, 0) <= COALESCE(OLD.revision, 0)) THEN
                NEW.deleted_at := OLD.deleted_at;
                NEW.updated_at := GREATEST(OLD.updated_at, COALESCE(NEW.updated_at, OLD.updated_at));
                NEW.revision := GREATEST(COALESCE(OLD.revision, 1), COALESCE(NEW.revision, 1));
            END IF;
        ELSE
            -- Ambos são tombstones: preserva a data de exclusão e avança metadados
            NEW.deleted_at := COALESCE(OLD.deleted_at, NEW.deleted_at);
            NEW.updated_at := GREATEST(OLD.updated_at, COALESCE(NEW.updated_at, OLD.updated_at));
            NEW.revision := GREATEST(COALESCE(OLD.revision, 1), COALESCE(NEW.revision, 1));
        END IF;
    END IF;

    -- 2. Se o registro está sendo marcado como tombstone nesta operação
    IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
        -- Garante que updated_at seja pelo menos igual a deleted_at para propagação incremental
        IF NEW.updated_at IS NULL OR NEW.updated_at < NEW.deleted_at THEN
            NEW.updated_at := NEW.deleted_at;
        END IF;
        -- Garante que a revisão seja incrementada para precedência determinística
        IF NEW.revision IS NULL OR NEW.revision <= COALESCE(OLD.revision, 0) THEN
            NEW.revision := COALESCE(OLD.revision, 0) + 1;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Vinculação do trigger BEFORE UPDATE às 10 tabelas sincronizadas
DO $$
DECLARE
    tbl text;
    tables text[] := ARRAY[
        'people', 'visits', 'bible_studies', 'study_participants', 
        'study_sessions', 'appointments', 'activity_records', 
        'voice_notes', 'phone_contacts', 'territory_landmarks'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_soft_delete_guard ON public.%I', tbl);
        EXECUTE format('
            CREATE TRIGGER trg_soft_delete_guard
            BEFORE UPDATE ON public.%I
            FOR EACH ROW
            EXECUTE FUNCTION public.handle_soft_delete_and_resurrection_guard()
        ', tbl);
    END LOOP;
END;
$$;

-- ============================================================================
-- SCRIPT DE ROLLBACK / REVERSÃO (se necessário):
-- ============================================================================
-- DO $$
-- DECLARE
--     tbl text;
--     tables text[] := ARRAY[
--         'people', 'visits', 'bible_studies', 'study_participants', 
--         'study_sessions', 'appointments', 'activity_records', 
--         'voice_notes', 'phone_contacts', 'territory_landmarks'
--     ];
-- BEGIN
--     FOREACH tbl IN ARRAY tables LOOP
--         EXECUTE format('DROP TRIGGER IF EXISTS trg_soft_delete_guard ON public.%I', tbl);
--     END LOOP;
-- END;
-- $$;
-- DROP FUNCTION IF EXISTS public.handle_soft_delete_and_resurrection_guard();
