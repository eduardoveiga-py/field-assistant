-- Optimistic compare-and-swap: o registro esperado é aquele lido pelo cliente.
-- Não substitui a função legada; clientes novos falham fechados até esta
-- migração ser implantada. SECURITY INVOKER preserva as políticas RLS.
CREATE OR REPLACE FUNCTION public.sync_upsert_if_unchanged(
    p_table TEXT,
    p_payload JSONB,
    p_expected_record JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_allowed CONSTANT TEXT[] := ARRAY[
        'people', 'visits', 'bible_studies', 'study_participants',
        'study_sessions', 'appointments', 'activity_records',
        'voice_notes', 'phone_contacts', 'territory_landmarks',
        'family_ties', 'ministry_experiences', 'person_photos',
        'person_publications', 'research_articles', 'research_tags',
        'territory_sectors', 'inbox_entries', 'projects', 'tasks',
        'knowledge_notes', 'knowledge_questions', 'knowledge_documents',
        'knowledge_resources', 'ticuna_words', 'ticuna_phrases'
    ];
    v_id TEXT;
    v_payload JSONB;
    v_existing JSONB;
    v_cols TEXT;
    v_vals TEXT;
    v_updates TEXT;
    v_affected INTEGER;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Autenticação obrigatória' USING ERRCODE = '42501';
    END IF;
    IF p_table IS NULL OR NOT (p_table = ANY(v_allowed)) THEN
        RAISE EXCEPTION 'Tabela não permitida: %', p_table USING ERRCODE = '42501';
    END IF;
    IF jsonb_typeof(p_payload) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION 'Payload inválido' USING ERRCODE = '22023';
    END IF;
    v_id := p_payload->>'id';
    IF v_id IS NULL OR length(trim(v_id)) = 0 THEN
        RAISE EXCEPTION 'ID obrigatório' USING ERRCODE = '22023';
    END IF;
    IF p_expected_record IS NOT NULL AND
       (jsonb_typeof(p_expected_record) IS DISTINCT FROM 'object' OR
        p_expected_record->>'id' IS DISTINCT FROM v_id OR
        p_expected_record->>'owner_id' IS DISTINCT FROM v_uid::TEXT) THEN
        RAISE EXCEPTION 'Estado esperado inválido' USING ERRCODE = '22023';
    END IF;

    v_payload := p_payload || jsonb_build_object('owner_id', v_uid::TEXT);
    SELECT string_agg(format('%I', c.column_name), ', '),
           string_agg(format('r.%I', c.column_name), ', '),
           string_agg(format('%I = EXCLUDED.%I', c.column_name, c.column_name), ', ')
      INTO v_cols, v_vals, v_updates
      FROM information_schema.columns c
     WHERE c.table_schema = 'public' AND c.table_name = p_table
       AND v_payload ? c.column_name;

    -- Se o cliente tinha visto um registro, não recriá-lo caso tenha sido
    -- apagado desde a leitura. O UPDATE é atômico e compara a linha inteira.
    IF p_expected_record IS NOT NULL THEN
        EXECUTE format(
            'UPDATE public.%I AS t SET (%s) = (SELECT %s FROM jsonb_populate_record(NULL::public.%I, $1) r) '
            'WHERE t.id::text = $2 AND t.owner_id = $3 AND to_jsonb(t) = $4',
            p_table, v_cols, v_vals, p_table
        ) USING v_payload, v_id, v_uid, p_expected_record;
    ELSE
        -- Um conflito de ID após a leitura significa que outro cliente inseriu.
        EXECUTE format(
            'INSERT INTO public.%I (%s) SELECT %s FROM jsonb_populate_record(NULL::public.%I, $1) r '
            'ON CONFLICT (id) DO NOTHING',
            p_table, v_cols, v_vals, p_table
        ) USING v_payload;
    END IF;
    GET DIAGNOSTICS v_affected = ROW_COUNT;
    IF v_affected = 0 THEN
        EXECUTE format('SELECT to_jsonb(t) FROM public.%I t WHERE t.id::text = $1 AND t.owner_id = $2', p_table)
          INTO v_existing USING v_id, v_uid;
        RETURN jsonb_build_object('success', false, 'conflict', true,
                                  'code', '23505', 'server_record', v_existing);
    END IF;
    RETURN jsonb_build_object('success', true, 'conflict', false, 'id', v_id);
END;
$$;

REVOKE ALL ON FUNCTION public.sync_upsert_if_unchanged(TEXT, JSONB, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sync_upsert_if_unchanged(TEXT, JSONB, JSONB) TO authenticated;
