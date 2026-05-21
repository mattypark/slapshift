// Supabase-backed per-IP rate limiter.
//
// No Redis. We log each attempt to `rate_limit_attempts` and count rows
// in the window. Good enough for v1 traffic; swap to Upstash later if
// /api/license/validate ever sees real load.
//
// Behavior on database errors: FAIL OPEN. We'd rather serve a legit user
// than 500 because Supabase had a hiccup. The endpoint is read-only and
// already requires a valid HMAC'd license key — a brute-force attacker
// can't grind through 2^140 keys regardless.

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
}): Promise<RateLimitResult> {
  const { ip, endpoint, limit, windowSeconds } = opts;
  const since = new Date(Date.now() - windowSeconds * 1000).toISOString();

  try {
    const { count, error: countErr } = await supabaseAdmin
      .from("rate_limit_attempts")
      .select("*", { count: "exact", head: true })
      .eq("ip", ip)
      .eq("endpoint", endpoint)
      .gte("created_at", since);

    if (countErr) {
      console.warn("[ratelimit] count failed, failing open:", countErr.message);
      return { ok: true, remaining: limit };
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
    console.warn("[ratelimit] error, failing open:", err);
    return { ok: true, remaining: limit };
  }
}

/** Extract client IP from a Next.js request. Falls back to "unknown" if no headers present. */
export function clientIp(req: Request): string {
  const fwd = req.headers.get("x-forwarded-for");
  if (fwd) return fwd.split(",")[0].trim();
  const real = req.headers.get("x-real-ip");
  if (real) return real.trim();
  return "unknown";
}
