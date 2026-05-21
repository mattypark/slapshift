// Centralized env access with fail-fast validation.
//
// Why: forgetting one env var in production silently breaks a route handler
// at request time. Validating once at module load fails the build instead.
//
// Usage: `import { env } from "@/app/lib/env"` — never `process.env.X` directly.

const required = [
  "NEXT_PUBLIC_SITE_URL",
  "NEXT_PUBLIC_SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "STRIPE_SECRET_KEY",
  "STRIPE_WEBHOOK_SECRET",
  "STRIPE_PRICE_ID",
  "RESEND_API_KEY",
  "RESEND_FROM_EMAIL",
  "LICENSE_HMAC_SECRET",
] as const;

type Required = (typeof required)[number];

function read(name: Required): string {
  const v = process.env[name];
  if (!v || v.length === 0) {
    throw new Error(
      `Missing required env var: ${name}. Set it in .env.local (or your Vercel env config). See .env.example.`,
    );
  }
  return v;
}

// Lazy proxy — only throws when a key is actually accessed at runtime.
// This lets `next build` succeed even if env isn't fully wired locally,
// because `process.env` substitution happens at build time for vars that
// are referenced in code paths reachable at build (mostly static pages).
export const env = new Proxy({} as Record<Required, string>, {
  get(_target, key: string) {
    if (!(required as readonly string[]).includes(key)) {
      throw new Error(`env.${key} is not declared in env.ts required list`);
    }
    return read(key as Required);
  },
});

// Optional (never throws):
export const optionalEnv = {
  dmgUrl: process.env.NEXT_PUBLIC_DMG_URL ?? "",
};
