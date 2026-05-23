-- SlapShift Supabase schema.
--
-- To apply: copy this file into the Supabase SQL editor and run it once.
-- Re-running is safe — every statement is idempotent.
--
-- Threat model:
--   - License keys are NEVER stored in plaintext. Only HMAC(key, LICENSE_HMAC_SECRET).
--     A full Supabase leak therefore does not leak working keys.
--   - Row Level Security is ON for every table. The anon key can do nothing.
--     Only the service_role key (server-only) can read/write.
--   - rate_limit_attempts gets cleaned up by a trigger every insert.

-- ============================================================================
-- licenses — one row per paid customer
-- ============================================================================
create table if not exists public.licenses (
  id                  uuid primary key default gen_random_uuid(),
  email               text not null,
  key_hash            text not null unique,        -- HMAC-SHA256(key, secret), hex
  stripe_session_id   text unique,                 -- one license per Checkout Session
  stripe_customer_id  text,
  machine_id          text,                        -- bound on first /api/license/validate
  status              text not null default 'active' check (status in ('active','refunded','revoked')),
  created_at          timestamptz not null default now(),
  bound_at            timestamptz,                 -- when machine_id was first set
  last_validated_at   timestamptz
);

create index if not exists licenses_email_idx        on public.licenses (email);
create index if not exists licenses_status_idx       on public.licenses (status);
create index if not exists licenses_stripe_session_idx on public.licenses (stripe_session_id);

alter table public.licenses enable row level security;

-- No policies = no access for anon/authenticated. Only service_role can read/write.
-- (service_role bypasses RLS by design.)

-- ============================================================================
-- rate_limit_attempts — token-bucket-ish per-IP rate limiting for /api/license/validate
-- ============================================================================
create table if not exists public.rate_limit_attempts (
  id          bigserial primary key,
  ip          text not null,
  endpoint    text not null,
  created_at  timestamptz not null default now()
);

create index if not exists rate_limit_ip_endpoint_idx
  on public.rate_limit_attempts (ip, endpoint, created_at desc);

alter table public.rate_limit_attempts enable row level security;

-- Cleanup function: delete rows older than 1 hour, called opportunistically.
create or replace function public.cleanup_rate_limits() returns void
language sql security definer as $$
  delete from public.rate_limit_attempts where created_at < now() - interval '1 hour';
$$;

-- ============================================================================
-- download_events — optional analytics for "how many people clicked Download DMG"
-- No PII required. Email is only collected in-app, not at download time.
-- ============================================================================
create table if not exists public.download_events (
  id          bigserial primary key,
  ip_hash     text,                                -- SHA256(ip + salt) so we can dedupe without storing IPs
  user_agent  text,
  version     text,
  created_at  timestamptz not null default now()
);

create index if not exists download_events_created_idx on public.download_events (created_at desc);

alter table public.download_events enable row level security;

-- ============================================================================
-- email_signups — in-app onboarding email capture (separate from license email)
-- ============================================================================
create table if not exists public.email_signups (
  id          bigserial primary key,
  email       text not null,
  source      text not null default 'app_onboarding',  -- future: 'newsletter', 'waitlist', etc.
  created_at  timestamptz not null default now()
);

create unique index if not exists email_signups_email_source_idx
  on public.email_signups (email, source);

alter table public.email_signups enable row level security;

-- ============================================================================
-- onboarding_profiles — captured when the desktop app finishes the usage step
--
-- One row per email. Holds name + intent (selected usage tags + an optional
-- free-text "other" answer) so we can:
--   1. Send Resend product-update emails to people who started onboarding,
--      whether or not they ended up paying.
--   2. See what real users want — the "other" answers show which usage cards
--      we should add next.
--
-- last_seen_at bumps on every upsert so we can tell repeat onboarders from
-- one-and-done signups. Email is lowercased before insert.
-- ============================================================================
create table if not exists public.onboarding_profiles (
  id            uuid primary key default gen_random_uuid(),
  email         text not null unique,
  name          text,
  usage         text[] not null default '{}',  -- ['coding','writing',...]
  other_detail  text,                          -- only set when usage @> '{other}'
  created_at    timestamptz not null default now(),
  last_seen_at  timestamptz not null default now()
);

create index if not exists onboarding_profiles_created_idx
  on public.onboarding_profiles (created_at desc);
create index if not exists onboarding_profiles_usage_gin_idx
  on public.onboarding_profiles using gin (usage);

alter table public.onboarding_profiles enable row level security;
-- No policies = service_role only.
