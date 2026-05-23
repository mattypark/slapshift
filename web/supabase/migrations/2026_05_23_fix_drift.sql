-- Re-syncs live Supabase to web/supabase/schema.sql.
--
-- Why: the validate endpoint started returning 500 with
--   "column licenses.bound_at does not exist"
-- and the profile endpoint with
--   "Could not find the table 'public.onboarding_profiles' in the schema cache"
-- because the live DB was last migrated before these were added to schema.sql.
--
-- Safe to re-run. Every statement is idempotent (ADD COLUMN IF NOT EXISTS,
-- CREATE TABLE IF NOT EXISTS, etc.).
--
-- To apply: paste into the Supabase SQL editor for project
-- wzeqxgovcehukbxgsnlk and run once. Then `NOTIFY pgrst, 'reload schema';`
-- at the bottom forces PostgREST to refresh its cached schema so the new
-- table/columns are immediately visible without a project restart.

-- ============================================================================
-- licenses: add machine-binding + validation tracking columns
-- ============================================================================
alter table public.licenses
  add column if not exists machine_id        text,
  add column if not exists bound_at          timestamptz,
  add column if not exists last_validated_at timestamptz;

-- ============================================================================
-- onboarding_profiles: missing table
-- ============================================================================
create table if not exists public.onboarding_profiles (
  id            uuid primary key default gen_random_uuid(),
  email         text not null unique,
  name          text,
  usage         text[] not null default '{}',
  other_detail  text,
  created_at    timestamptz not null default now(),
  last_seen_at  timestamptz not null default now()
);

create index if not exists onboarding_profiles_created_idx
  on public.onboarding_profiles (created_at desc);
create index if not exists onboarding_profiles_usage_gin_idx
  on public.onboarding_profiles using gin (usage);

alter table public.onboarding_profiles enable row level security;
-- No policies = service_role only.

-- ============================================================================
-- Force PostgREST to reload — otherwise the API keeps returning
-- "Could not find the table in the schema cache" for ~10 minutes.
-- ============================================================================
notify pgrst, 'reload schema';
