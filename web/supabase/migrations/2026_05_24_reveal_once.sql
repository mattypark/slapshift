-- Reveal-once guard on /success.
--
-- Closes the leak path where anyone with a session_id (from Vercel logs,
-- analytics, referer, browser history) could fetch /success?session_id=...
-- and see the plaintext license key indefinitely.
--
-- After this migration: /success atomically marks revealed_at=now() the first
-- time it shows the key. Subsequent fetches return "check your email" instead
-- of the key, so log-mining can't recover a working credential.
--
-- To apply: paste into Supabase SQL editor and run once. Idempotent.

alter table public.licenses
  add column if not exists revealed_at timestamptz;

-- Force PostgREST to reload its schema cache so the new column is visible
-- without a project restart.
notify pgrst, 'reload schema';
