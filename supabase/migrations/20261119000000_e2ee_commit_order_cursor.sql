-- Fix per-owner pull cursor commit ordering. Apply only while sync is disabled.
-- This migration does not repair records skipped by an older client cursor.
BEGIN;

-- ACCESS EXCLUSIVE is retained until commit: any old in-flight writes drain
-- before changing the writer and the migration snapshot/floor are established.
ALTER TABLE public.encrypted_records ALTER COLUMN server_seq DROP DEFAULT;

CREATE TABLE IF NOT EXISTS public.encrypted_record_owner_cursors (
    owner_id uuid PRIMARY KEY,
    last_seq bigint NOT NULL CHECK (last_seq BETWEEN 1 AND 9007199254740991),
    writer_xid xid8 NOT NULL
);
ALTER TABLE public.encrypted_record_owner_cursors ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.encrypted_record_owner_cursors FROM PUBLIC, anon, authenticated;

-- Freeze a conservative floor for any previously issued cursor. Keeping it in
-- a private singleton avoids a full-table scan for every future write.
CREATE TABLE IF NOT EXISTS public.encrypted_record_cursor_baseline (
    singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
    legacy_floor bigint NOT NULL CHECK (legacy_floor >= 0)
);
ALTER TABLE public.encrypted_record_cursor_baseline ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.encrypted_record_cursor_baseline FROM PUBLIC, anon, authenticated;
INSERT INTO public.encrypted_record_cursor_baseline AS b (singleton, legacy_floor)
SELECT true, GREATEST(
    (SELECT last_value FROM public.encrypted_records_server_seq_seq),
    COALESCE((SELECT max(server_seq) FROM public.encrypted_records), 0)
)
ON CONFLICT (singleton) DO UPDATE
SET legacy_floor = GREATEST(b.legacy_floor, EXCLUDED.legacy_floor);

-- Reject stale in-flight writers that entered the old RPC before cutover and
-- resume after the table lock is released. Privileged operators can bypass a
-- trigger, so maintenance must still stop and drain writers before migration.
CREATE OR REPLACE FUNCTION public.encrypted_record_cursor_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.encrypted_record_owner_cursors c
        WHERE c.owner_id = NEW.owner_id
          AND c.last_seq = NEW.server_seq
          AND c.writer_xid = pg_current_xact_id()
    ) THEN
        RAISE EXCEPTION 'Escrita cifrada sem cursor transacional' USING ERRCODE = '55000';
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.encrypted_record_cursor_guard() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS encrypted_record_cursor_guard ON public.encrypted_records;
CREATE TRIGGER encrypted_record_cursor_guard
BEFORE INSERT OR UPDATE ON public.encrypted_records
FOR EACH ROW EXECUTE FUNCTION public.encrypted_record_cursor_guard();

CREATE OR REPLACE FUNCTION public.encrypted_record_cas(
    p_route text,
    p_expected_revision bigint,
    p_envelope jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_count integer;
    v_revision bigint;
    v_server_seq bigint;
    v_legacy_floor bigint;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Autenticação obrigatória' USING ERRCODE = '42501';
    END IF;
    IF p_route IS NULL OR p_route !~ '^[0-9a-f]{64}$' OR
       p_expected_revision IS NULL OR p_expected_revision < 0 OR
       p_expected_revision >= 9007199254740991 THEN
        RAISE EXCEPTION 'Rota ou revisão inválida' USING ERRCODE = '22023';
    END IF;
    IF p_envelope IS NULL OR jsonb_typeof(p_envelope) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION 'Envelope inválido' USING ERRCODE = '22023';
    END IF;
    SELECT count(*) INTO v_count FROM jsonb_object_keys(p_envelope);
    IF v_count != 5 OR p_envelope->'v' IS DISTINCT FROM '1'::jsonb OR
       p_envelope->>'algorithm' IS DISTINCT FROM 'A256GCM' OR
       jsonb_typeof(p_envelope->'nonce') IS DISTINCT FROM 'string' OR
       jsonb_typeof(p_envelope->'tag') IS DISTINCT FROM 'string' OR
       jsonb_typeof(p_envelope->'ciphertext') IS DISTINCT FROM 'string' OR
       length(p_envelope->>'nonce') != 16 OR length(p_envelope->>'tag') != 24 OR
       length(p_envelope->>'ciphertext') > 1398104 THEN
        RAISE EXCEPTION 'Envelope inválido' USING ERRCODE = '22023';
    END IF;

    -- This row remains locked until the encompassing transaction commits or
    -- rolls back, serializing cursor allocation for this owner only. Never
    -- advance past the JS-safe range used by clients.
    SELECT legacy_floor INTO STRICT v_legacy_floor
      FROM public.encrypted_record_cursor_baseline WHERE singleton;
    IF v_legacy_floor >= 9007199254740991 THEN
        RAISE EXCEPTION 'Cursor cifrado esgotado' USING ERRCODE = '22003';
    END IF;
    INSERT INTO public.encrypted_record_owner_cursors AS c(owner_id, last_seq, writer_xid)
    VALUES (v_uid, v_legacy_floor + 1, pg_current_xact_id())
    ON CONFLICT (owner_id) DO UPDATE
       SET last_seq = GREATEST(c.last_seq, v_legacy_floor) + 1,
           writer_xid = pg_current_xact_id()
     WHERE GREATEST(c.last_seq, v_legacy_floor) < 9007199254740991
    RETURNING last_seq INTO v_server_seq;
    IF v_server_seq IS NULL THEN
        RAISE EXCEPTION 'Cursor cifrado esgotado' USING ERRCODE = '22003';
    END IF;

    IF p_expected_revision = 0 THEN
        INSERT INTO public.encrypted_records(owner_id, route, revision, envelope, server_seq)
        VALUES (v_uid, p_route, 1, p_envelope, v_server_seq)
        ON CONFLICT (owner_id, route) DO NOTHING
        RETURNING server_seq INTO v_server_seq;
    ELSE
        UPDATE public.encrypted_records
           SET revision = p_expected_revision + 1,
               envelope = p_envelope,
               server_seq = v_server_seq
         WHERE owner_id = v_uid
           AND route = p_route
           AND revision = p_expected_revision
        RETURNING server_seq INTO v_server_seq;
    END IF;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    IF v_count = 1 THEN
        RETURN jsonb_build_object(
            'success', true,
            'revision', p_expected_revision + 1,
            'server_seq', v_server_seq
        );
    END IF;
    SELECT revision INTO v_revision
      FROM public.encrypted_records
     WHERE owner_id = v_uid AND route = p_route;
    RETURN jsonb_build_object(
        'success', false,
        'conflict', true,
        'revision', v_revision
    );
END;
$$;

REVOKE ALL ON FUNCTION public.encrypted_record_cas(text, bigint, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.encrypted_record_cas(text, bigint, jsonb) TO authenticated;

COMMIT;
