-- Migração E2EE Reconciliação Histórica (FA-REGIONAL-MAPS-STAGING / R1)
-- Adiciona RPCs autenticadas para reconciliação histórica e paginação estável por ordem binária C:
-- 1. encrypted_records_reconcile_start(): retorna watermark da conta baseado no contador ou piso legado (0).
-- 2. encrypted_records_scan_page(after_route, limit): paginação estável ordenada por (route COLLATE "C"),
--    rejeitando rotas não hexadecimais, mantendo isolamento de conta e sem expor plaintext.

-- 1. Restrição de validação para garantir que server_seq seja sempre positivo
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_encrypted_records_server_seq_positive'
    ) THEN
        ALTER TABLE public.encrypted_records
            ADD CONSTRAINT chk_encrypted_records_server_seq_positive CHECK (server_seq > 0);
    END IF;
END $$;

-- 2. Índice composto otimizado para paginação por colação binária C
CREATE INDEX IF NOT EXISTS idx_encrypted_records_owner_route_c
    ON public.encrypted_records (owner_id, (route COLLATE "C"));

-- 3. RPC: public.encrypted_records_reconcile_start
CREATE OR REPLACE FUNCTION public.encrypted_records_reconcile_start()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_watermark bigint;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Autenticação obrigatória' USING ERRCODE = '42501';
    END IF;

    SELECT COALESCE(MAX(server_seq), 0)
      INTO v_watermark
      FROM public.encrypted_records
     WHERE owner_id = v_uid;

    RETURN v_watermark;
END;
$$;

REVOKE ALL ON FUNCTION public.encrypted_records_reconcile_start() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.encrypted_records_reconcile_start() TO authenticated;

-- 4. RPC: public.encrypted_records_scan_page
CREATE OR REPLACE FUNCTION public.encrypted_records_scan_page(
    p_after_route text DEFAULT NULL,
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

    -- Rejeição estrita de rotas que não sejam SHA-256 hexadecimais (64 caracteres)
    IF p_after_route IS NOT NULL AND p_after_route !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION 'Rota hexadecimal inválida' USING ERRCODE = '22023';
    END IF;

    v_limit := LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);

    RETURN QUERY
    SELECT er.route, er.revision, er.server_seq, er.envelope
      FROM public.encrypted_records er
     WHERE er.owner_id = v_uid
       AND (p_after_route IS NULL OR (er.route COLLATE "C") > (p_after_route COLLATE "C"))
     ORDER BY (er.route COLLATE "C") ASC
     LIMIT v_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.encrypted_records_scan_page(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.encrypted_records_scan_page(text, integer) TO authenticated;
