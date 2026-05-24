// Supabase-backed per-IP rate limiter.
//
// No Redis. We log each attempt to `rate_limit_attempts` and count rows
// in the window. Good enough for v1 traffic; swap to Upstash later if
// /api/license/validate ever sees real load.
//
// Behavior on database errors: configurable via `failOpen`.
//
//   failOpen: false (DEFAULT) — when the DB is unreachable we treat the
//     request as if the limit was hit. This is the safe default for any
//     endpoint that wires payment, account creation, or mutation. A brief
//     Supabase outage causing 429s is far cheaper than letting an attacker
//     amplify spend or spray the database because rate limiting silently
//     disabled itself.
//
//   failOpen: true — only for endpoints where the underlying action is
//     already cryptographically gated (e.g. /api/license/validate, which
//     requires a valid HMAC'd key — 2^140 brute-force floor) AND where a
//     false 429 would break a legit logged-in user's workflow.
//
// The previous default was fail-OPEN globally. That meant a Supabase blip
// effectively disabled rate limiting on /api/checkout (Stripe Session
// creation costs money) and /api/profile. Default is now fail-CLOSED.

import "server-only";
import { supabaseAdmin } from "./supabase";

export interface RateLimitResult {
  ok: boolean;
  remaining: number;
}

export async function checkRateLimit(opts: {
  ip: string;
  endpoint: string;
  limit: number;
  windowSeconds: number;
  /**
   * What to do when the rate-limit backend itself errors.
   * Default: false (fail CLOSED — treat as over-limit).
   * Set true only for endpoints whose underlying action is already
   * cryptographically gated and where a false 429 would break legit users.
   */
  failOpen?: boolean;
}): Promise<RateLimitResult> {
  const { ip, endpoint, limit, windowSeconds, failOpen = false } = opts;
  const since = new Date(Date.now() - windowSeconds * 1000).toISOString();

  const onBackendError = (msg: string): RateLimitResult => {
    if (failOpen) {
      console.warn(`[ratelimit] ${endpoint}: ${msg} — failing OPEN (failOpen=true)`);
      return { ok: true, remaining: limit };
    }
    console.warn(`[ratelimit] ${endpoint}: ${msg} — failing CLOSED (default)`);
    return { ok: false, remaining: 0 };
  };

  try {
    const { count, error: countErr } = await supabaseAdmin
      .from("rate_limit_attempts")
      .select("*", { count: "exact", head: true })
      .eq("ip", ip)
      .eq("endpoint", endpoint)
      .gte("created_at", since);

    if (countErr) {
      return onBackendError(`count failed: ${countErr.message}`);
    }

    const used = count ?? 0;
    if (used >= limit) {
      return { ok: false, remaining: 0 };
    }

    // Record this attempt. Best-effort.
    await supabaseAdmin.from("rate_limit_attempts").insert({ ip, endpoint });

    // Opportunistic cleanup (1% of requests trigger a sweep).
    if (Math.random() < 0.01) {
      void supabaseAdmin.rpc("cleanup_rate_limits");
    }

    return { ok: true, remaining: limit - used - 1 };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return onBackendError(`threw: ${msg}`);
  }
}

/**
 * Extract client IP from a Next.js request.
 *
 * Header preference (most-trusted → least-trusted):
 *   1. `x-vercel-forwarded-for` — set by Vercel's edge after stripping any
 *      caller-supplied value. Cannot be spoofed by a client request because
 *      Vercel overwrites it. ALWAYS prefer this when running on Vercel.
 *   2. `x-forwarded-for` — standard but client-controllable on most platforms.
 *      Take the LEFTMOST entry (closest to the original client) per the
 *      Forwarded header convention. Still spoofable end-to-end if no proxy
 *      rewrites it, so it's a fallback for non-Vercel deploys.
 *   3. `x-real-ip` — Nginx-style fallback.
 *   4. "unknown" — bucket everyone here. The /api/checkout and /api/profile
 *      handlers use this same value for the rate-limit key, so an attacker
 *      who strips all headers ends up self-rate-limited into a shared bucket.
 */
export function clientIp(req: Request): string {
  const vercel = req.headers.get("x-vercel-forwarded-for");
  if (vercel) return vercel.split(",")[0].trim();
  const fwd = req.headers.get("x-forwarded-for");
  if (fwd) return fwd.split(",")[0].trim();
  const real = req.headers.get("x-real-ip");
  if (real) return real.trim();
  return "unknown";
}
