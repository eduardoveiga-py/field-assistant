-- Experimental: instalação atômica e imutável de marcador de cofre por conta.
-- Não ativa sincronização, não migra dados e não protege contra um servidor
-- malicioso que oculte ou reapresente dados antigos.
CREATE TABLE public.experimental_recovery_vaults (
    owner_id uuid PRIMARY KEY,
    marker jsonb NOT NULL
);
ALTER TABLE public.experimental_recovery_vaults ENABLE ROW LEVEL SECURITY;
CREATE POLICY experimental_recovery_vaults_read_own
    ON public.experimental_recovery_vaults FOR SELECT TO authenticated
    USING (owner_id = auth.uid());
REVOKE ALL ON public.experimental_recovery_vaults FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.experimental_recovery_vaults TO authenticated;

CREATE FUNCTION public.experimental_recovery_vault_create(p_marker jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_count integer;
    v_box jsonb;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Autenticação obrigatória' USING ERRCODE = '42501';
    END IF;
    IF p_marker IS NULL OR jsonb_typeof(p_marker) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION 'Marcador inválido' USING ERRCODE = '22023';
    END IF;
    SELECT count(*) INTO v_count FROM jsonb_object_keys(p_marker);
    IF v_count != 3 OR p_marker->'version' IS DISTINCT FROM '1'::jsonb OR
       jsonb_typeof(p_marker->'vaultId') IS DISTINCT FROM 'string' OR
       p_marker->>'vaultId' !~ '^[0-9a-f]{32}$' OR
       jsonb_typeof(p_marker->'envelope') IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION 'Marcador inválido' USING ERRCODE = '22023';
    END IF;
    v_box := p_marker->'envelope';
    SELECT count(*) INTO v_count FROM jsonb_object_keys(v_box);
    IF v_count != 5 OR v_box->'v' IS DISTINCT FROM '1'::jsonb OR
       v_box->>'algorithm' IS DISTINCT FROM 'A256GCM' OR
       jsonb_typeof(v_box->'nonce') IS DISTINCT FROM 'string' OR
       jsonb_typeof(v_box->'tag') IS DISTINCT FROM 'string' OR
       jsonb_typeof(v_box->'ciphertext') IS DISTINCT FROM 'string' OR
       length(v_box->>'nonce') != 16 OR length(v_box->>'tag') != 24 OR
       length(v_box->>'ciphertext') > 4096 THEN
        RAISE EXCEPTION 'Envelope de marcador inválido' USING ERRCODE = '22023';
    END IF;
    INSERT INTO public.experimental_recovery_vaults(owner_id, marker)
    VALUES (v_uid, p_marker) ON CONFLICT (owner_id) DO NOTHING;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    IF v_count = 1 THEN RETURN jsonb_build_object('success', true); END IF;
    RETURN jsonb_build_object('success', false, 'conflict', true);
END;
$$;
REVOKE ALL ON FUNCTION public.experimental_recovery_vault_create(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.experimental_recovery_vault_create(jsonb) TO authenticated;
