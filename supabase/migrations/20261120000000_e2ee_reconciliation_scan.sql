-- Foundation for a future authenticated reconciliation, NOT a completed client.
-- Apply only to an isolated staging environment after stopping/draining writers
-- and installing the transactional cursor migration. Does not alter records.
BEGIN;

-- Match the deterministic C collation used by the keyset scan.
CREATE INDEX IF NOT EXISTS encrypted_records_owner_route_c_idx
    ON public.encrypted_records (owner_id, route COLLATE "C");

CREATE OR REPLACE FUNCTION public.encrypted_records_reconcile_start()
RETURNS bigint
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_watermark bigint;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Autenticação obrigatória' USING ERRCODE = '42501';
    END IF;
    -- One read-committed statement snapshot. The transactional owner counter
    -- is held until its writer commits, so an uncommitted write must later have
    -- a cursor strictly greater than this committed watermark.
    SELECT GREATEST(
        b.legacy_floor,
        COALESCE(c.last_seq, 0)
    ) INTO STRICT v_watermark
    FROM public.encrypted_record_cursor_baseline b
    LEFT JOIN public.encrypted_record_owner_cursors c ON c.owner_id = v_uid
    WHERE b.singleton;
    IF v_watermark < 0 OR v_watermark > 9007199254740991 THEN
        RAISE EXCEPTION 'Cursor de reconciliação inválido' USING ERRCODE = '22003';
    END IF;
    RETURN v_watermark;
END;
$$;
REVOKE ALL ON FUNCTION public.encrypted_records_reconcile_start() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.encrypted_records_reconcile_start() TO authenticated;

CREATE OR REPLACE FUNCTION public.encrypted_records_scan_page(
    p_after_route text DEFAULT NULL,
    p_limit integer DEFAULT 100
) RETURNS TABLE (
    route text,
    revision bigint,
    server_seq bigint,
    envelope jsonb
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Autenticação obrigatória' USING ERRCODE = '42501';
    END IF;
    IF p_after_route IS NOT NULL AND p_after_route !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION 'Rota de reconciliação inválida' USING ERRCODE = '22023';
    END IF;
    IF p_limit IS NULL OR p_limit < 1 OR p_limit > 500 THEN
        RAISE EXCEPTION 'Limite de reconciliação inválido' USING ERRCODE = '22023';
    END IF;
    RETURN QUERY
    SELECT er.route, er.revision, er.server_seq, er.envelope
    FROM public.encrypted_records er
    WHERE er.owner_id = v_uid
      AND (p_after_route IS NULL OR er.route COLLATE "C" > p_after_route COLLATE "C")
    ORDER BY er.route COLLATE "C"
    LIMIT p_limit;
END;
$$;
REVOKE ALL ON FUNCTION public.encrypted_records_scan_page(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.encrypted_records_scan_page(text, integer) TO authenticated;
COMMIT;
