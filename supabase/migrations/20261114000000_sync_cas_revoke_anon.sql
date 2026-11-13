-- Supabase default privileges may grant new public functions to anon directly.
-- Keep the compare-and-swap RPC executable only by authenticated clients.
REVOKE ALL ON FUNCTION public.sync_upsert_if_unchanged(TEXT, JSONB, JSONB) FROM anon;
REVOKE ALL ON FUNCTION public.sync_upsert_if_unchanged(TEXT, JSONB, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sync_upsert_if_unchanged(TEXT, JSONB, JSONB) TO authenticated;
