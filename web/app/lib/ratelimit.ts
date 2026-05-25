// Supabase-backed per-IP rate limiter.
//
// No Redis. We log each attempt to `rate_limit_attempts` and count rows
// in the window. Good enough for v1 traffic; swap to Upstash later if
// /api/license/validate ever sees real load.
//
// Behavior on database errors: FAIL OPEN by default.
//
// We tried fail-closed-by-default and it bit real users — the Supabase
// count query intermittently returns an empty-message error that has no
// stable signal we can distinguish from "DB is dead", so flipping closed
// produced spurious 429s mid-onboarding and broke the funnel. The
// underlying mutations are not catastrophic at v1 scale:
//   - /api/checkout creates a Stripe Session, which itself is rate-limited
//     by Stripe and costs nothing until the buyer enters card details.
//   - /api/profile inserts a row into onboarding_profiles. Spam is annoying
//     (cleanable) but not destructive.
//   - /api/license/validate is HMAC-gated (2^140 brute-force floor) — even
//     fully disabled rate limiting cannot be amplified into key compromise.
// If we ever ship something where amplification IS catastrophic (e.g. an
// endpoint that sends email per call), pass `failOpen: false` explicitly.
//
// We also ignore "errors" whose message is empty. The Supabase JS client
// occasionally surfaces a falsy-message error object when PostgREST returns
// a non-2xx that's actually a normal empty-result for a HEAD count. Treating
// that as a backend failure was the proximate cause of the production
// 429-storm; gating on `err.message?.length` filters it out cleanly.

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
   * Default: true (fail OPEN — serve the request rather than 429 a legit user).
   * Pass false ONLY for endpoints where a failed rate-limit check would let
   * an attacker amplify a costly side effect (email send, paid API call,
   * destructive DB op).
   */
  failOpen?: boolean;
}): Promise<RateLimitResult> {
  const { ip, endpoint, limit, windowSeconds, failOpen = true } = opts;
  const since = new Date(Date.now() - windowSeconds * 1000).toISOString();

  const onBackendError = (msg: string): RateLimitResult => {
    if (failOpen) {
      console.warn(`[ratelimit] ${endpoint}: ${msg} — failing OPEN`);
      return { ok: true, remaining: limit };
    }
    console.warn(`[ratelimit] ${endpoint}: ${msg} — failing CLOSED (explicit failOpen=false)`);
    return { ok: false, remaining: 0 };
  };

  try {
    const { count, error: countErr } = await supabaseAdmin
      .from("rate_limit_attempts")
      .select("*", { count: "exact", head: true })
      .eq("ip", ip)
      .eq("endpoint", endpoint)
      .gte("created_at", since);

    // Only treat as a real backend error if the error has a message. An
    // empty-message error is the spurious case described above and should
    // be treated as "0 attempts seen in window".
    if (countErr && countErr.message && countErr.message.length > 0) {
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
