CREATE TABLE IF NOT EXISTS public.voice_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT,
    audio_path TEXT,
    duration INTEGER,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.voice_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own voice_notes"
    ON public.voice_notes
    FOR ALL
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

CREATE TABLE IF NOT EXISTS public.phone_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone_number TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.phone_contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own phone_contacts"
    ON public.phone_contacts
    FOR ALL
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

CREATE TABLE IF NOT EXISTS public.territory_landmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.territory_landmarks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own territory_landmarks"
    ON public.territory_landmarks
    FOR ALL
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

INSERT INTO storage.buckets (id, name, public)
VALUES ('voice_notes', 'voice_notes', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Users can access their own voice_notes storage objects"
    ON storage.objects
    FOR ALL
    USING (bucket_id = 'voice_notes' AND auth.uid() = (storage.foldername(name))[1]::uuid)
    WITH CHECK (bucket_id = 'voice_notes' AND auth.uid() = (storage.foldername(name))[1]::uuid);

INSERT INTO storage.buckets (id, name, public)
VALUES ('ticuna_audio', 'ticuna_audio', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Users can access their own ticuna_audio storage objects"
    ON storage.objects
    FOR ALL
    USING (bucket_id = 'ticuna_audio' AND auth.uid() = (storage.foldername(name))[1]::uuid)
    WITH CHECK (bucket_id = 'ticuna_audio' AND auth.uid() = (storage.foldername(name))[1]::uuid);

