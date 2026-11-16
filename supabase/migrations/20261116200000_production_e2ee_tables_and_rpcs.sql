-- Migração de Produção E2EE: Tabelas definitivas de registros cifrados e cofre de chaves
-- Criptografia de Ponta a Ponta (E2EE) com derivação BIP-39 e envelopes AES-256-GCM.

CREATE TABLE IF NOT EXISTS public.encrypted_records (
    owner_id uuid NOT NULL,
    route text NOT NULL CHECK (route ~ '^[0-9a-f]{64}$'),
    revision bigint NOT NULL CHECK (revision BETWEEN 1 AND 9007199254740991),
    envelope jsonb NOT NULL,
    PRIMARY KEY (owner_id, route)
);

ALTER TABLE public.encrypted_records ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'encrypted_records' AND policyname = 'encrypted_records_read_own'
    ) THEN
        CREATE POLICY encrypted_records_read_own
            ON public.encrypted_records FOR SELECT TO authenticated
            USING (owner_id = auth.uid());
    END IF;
END $$;

REVOKE ALL ON public.encrypted_records FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.encrypted_records TO authenticated;

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
        ON CONFLICT (owner_id, route) DO NOTHING;
    ELSE
        UPDATE public.encrypted_records
           SET revision = p_expected_revision + 1, envelope = p_envelope
         WHERE owner_id = v_uid AND route = p_route AND revision = p_expected_revision;
    END IF;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    IF v_count = 1 THEN
        RETURN jsonb_build_object('success', true, 'revision', p_expected_revision + 1);
    END IF;
    SELECT revision INTO v_revision FROM public.encrypted_records
     WHERE owner_id = v_uid AND route = p_route;
    RETURN jsonb_build_object('success', false, 'conflict', true, 'revision', v_revision);
END;
$$;

REVOKE ALL ON FUNCTION public.encrypted_record_cas(text, bigint, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.encrypted_record_cas(text, bigint, jsonb) TO authenticated;

-- Tabela de Cofres de Recuperação E2EE (Recovery Vaults)
CREATE TABLE IF NOT EXISTS public.recovery_vaults (
    owner_id uuid PRIMARY KEY,
    marker jsonb NOT NULL
);

ALTER TABLE public.recovery_vaults ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'recovery_vaults' AND policyname = 'recovery_vaults_read_own'
    ) THEN
        CREATE POLICY recovery_vaults_read_own
            ON public.recovery_vaults FOR SELECT TO authenticated
            USING (owner_id = auth.uid());
    END IF;
END $$;

REVOKE ALL ON public.recovery_vaults FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.recovery_vaults TO authenticated;

CREATE OR REPLACE FUNCTION public.recovery_vault_create(p_marker jsonb)
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

    INSERT INTO public.recovery_vaults(owner_id, marker)
    VALUES (v_uid, p_marker) ON CONFLICT (owner_id) DO NOTHING;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    IF v_count = 1 THEN RETURN jsonb_build_object('success', true); END IF;
    RETURN jsonb_build_object('success', false, 'conflict', true);
END;
$$;

REVOKE ALL ON FUNCTION public.recovery_vault_create(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recovery_vault_create(jsonb) TO authenticated;
