-- Infraestrutura experimental: NÃO ativa a sincronização nem migra o legado.
-- Aplicar apenas em projeto de teste depois de revisar a migração completa.
-- O servidor não consegue verificar se o cliente realmente cifrou o envelope.
CREATE TABLE public.experimental_encrypted_records (
    owner_id uuid NOT NULL,
    route text NOT NULL CHECK (route ~ '^[0-9a-f]{64}$'),
    revision bigint NOT NULL CHECK (revision BETWEEN 1 AND 9007199254740991),
    envelope jsonb NOT NULL,
    PRIMARY KEY (owner_id, route)
);

ALTER TABLE public.experimental_encrypted_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY experimental_encrypted_records_read_own
    ON public.experimental_encrypted_records FOR SELECT TO authenticated
    USING (owner_id = auth.uid());

-- Nenhum cliente pode escrever diretamente, pular a verificação de revisão ou
-- apagar linhas; o RPC abaixo deriva o proprietário exclusivamente de auth.uid().
REVOKE ALL ON public.experimental_encrypted_records FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.experimental_encrypted_records TO authenticated;

CREATE FUNCTION public.experimental_encrypted_record_cas(
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
        INSERT INTO public.experimental_encrypted_records(owner_id, route, revision, envelope)
        VALUES (v_uid, p_route, 1, p_envelope)
        ON CONFLICT (owner_id, route) DO NOTHING;
    ELSE
        UPDATE public.experimental_encrypted_records
           SET revision = p_expected_revision + 1, envelope = p_envelope
         WHERE owner_id = v_uid AND route = p_route AND revision = p_expected_revision;
    END IF;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    IF v_count = 1 THEN
        RETURN jsonb_build_object('success', true, 'revision', p_expected_revision + 1);
    END IF;
    SELECT revision INTO v_revision FROM public.experimental_encrypted_records
     WHERE owner_id = v_uid AND route = p_route;
    RETURN jsonb_build_object('success', false, 'conflict', true, 'revision', v_revision);
END;
$$;
REVOKE ALL ON FUNCTION public.experimental_encrypted_record_cas(text, bigint, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.experimental_encrypted_record_cas(text, bigint, jsonb) TO authenticated;
