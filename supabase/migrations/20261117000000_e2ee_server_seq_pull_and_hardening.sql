-- Migração E2EE Fase 1 (FA-SEC-02): Cursor monotônico server_seq, pull paginado cifrado e endurecimento.
-- Estritamente aditiva e idempotente para preservar registros existentes.

ALTER TABLE public.encrypted_records
    ADD COLUMN IF NOT EXISTS server_seq BIGSERIAL NOT NULL;

CREATE INDEX IF NOT EXISTS idx_encrypted_records_owner_server_seq
    ON public.encrypted_records (owner_id, server_seq);

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

    IF p_expected_revision = 0 THEN
        INSERT INTO public.encrypted_records(owner_id, route, revision, envelope)
        VALUES (v_uid, p_route, 1, p_envelope)
        ON CONFLICT (owner_id, route) DO NOTHING
        RETURNING server_seq INTO v_server_seq;
    ELSE
        UPDATE public.encrypted_records
           SET revision = p_expected_revision + 1,
               envelope = p_envelope,
               server_seq = nextval(pg_get_serial_sequence('public.encrypted_records', 'server_seq'))
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

CREATE OR REPLACE FUNCTION public.encrypted_records_pull_since(
    p_since_seq bigint DEFAULT 0,
    p_limit integer DEFAULT 100
) RETURNS TABLE (
    route text,
    revision bigint,
    server_seq bigint,
    envelope jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_limit integer;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Autenticação obrigatória' USING ERRCODE = '42501';
    END IF;
    IF p_since_seq IS NULL OR p_since_seq < 0 THEN
        RAISE EXCEPTION 'Cursor server_seq inválido' USING ERRCODE = '22023';
    END IF;
    v_limit := LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);

    RETURN QUERY
    SELECT er.route, er.revision, er.server_seq, er.envelope
      FROM public.encrypted_records er
     WHERE er.owner_id = v_uid
       AND er.server_seq > p_since_seq
     ORDER BY er.server_seq ASC
     LIMIT v_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.encrypted_records_pull_since(bigint, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.encrypted_records_pull_since(bigint, integer) TO authenticated;
