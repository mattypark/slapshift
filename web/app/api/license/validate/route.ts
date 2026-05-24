// POST /api/license/validate
//
// Called by the SlapShift Mac app on launch + periodically (every 30 days).
//
// Request:  { "key": "SLAP-...", "machineId": "uuid-from-IORegistry" }
// Response:
//   { ok: true,  expiresAt: <ISO>, email: "user@..." }   — valid
//   { ok: false, reason: "not_found" | "refunded" | "machine_mismatch" | "rate_limited" }
//
// Machine binding: the first machine to validate a key binds it. Subsequent
// validations from a different machine_id are rejected. This is the lightest-
// weight piracy deterrent — a single key can't be shared across an unlimited
// number of friends. Users who legitimately need to switch Macs can email
// support for an unbind.
//
// Rate limiting: 10 attempts per minute per IP. Brute-force is already
// infeasible (140 bits of entropy) but the limit stops accidental hammering
// from a buggy app build.

import { NextResponse } from "next/server";
import { supabaseAdmin } from "@/app/lib/supabase";
import { hashKey, looksLikeKey } from "@/app/lib/license";
import { checkRateLimit, clientIp } from "@/app/lib/ratelimit";

export const dynamic = "force-dynamic";

const GRACE_DAYS = 30;

export async function POST(req: Request) {
  const ip = clientIp(req);

  // failOpen: true here is intentional. This endpoint is the Mac app's
  // periodic heartbeat — a Supabase blip causing a 429 would erroneously
  // start the 30-day grace clock on legit users. The underlying action
  // is already cryptographically gated (the request must HMAC-match a
  // 140-bit key in the DB), so a brief loss of rate-limiting can't be
  // abused for brute force. Checkout + profile stay fail-CLOSED.
  const rl = await checkRateLimit({
    ip,
    endpoint: "license_validate",
    limit: 10,
    windowSeconds: 60,
    failOpen: true,
  });
  if (!rl.ok) {
    return NextResponse.json({ ok: false, reason: "rate_limited" }, { status: 429 });
  }

  let body: { key?: unknown; machineId?: unknown };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ ok: false, reason: "bad_request" }, { status: 400 });
  }

  const key = typeof body.key === "string" ? body.key : "";
  const machineId = typeof body.machineId === "string" ? body.machineId : "";

  if (!looksLikeKey(key)) {
    // Distinguish format failures from DB misses so the buyer sees the
    // right error. Old behavior returned "not_found" for both, which
    // hid copy/paste typos behind a misleading "key doesn't exist".
    // Log codepoints (not the key itself) so we can see if a hidden
    // unicode char (ZWSP, NBSP, em-dash) snuck in from a Gmail copy.
    const codepoints = Array.from(key).map((c) => c.charCodeAt(0).toString(16)).join(",");
    console.warn(
      "[validate] bad_format len=%d prefix=%s codepoints=%s",
      key.length,
      key.slice(0, 6),
      codepoints,
    );
    return NextResponse.json({ ok: false, reason: "bad_format" }, { status: 400 });
  }
  if (machineId.length === 0 || machineId.length > 128) {
    return NextResponse.json({ ok: false, reason: "bad_request" }, { status: 400 });
  }

  const keyHash = hashKey(key);
  // Log first 8 hex chars only so we can correlate failures against the
  // DB without ever putting the full hash in logs. Full hash is sensitive
  // because it equals the stored credential.
  const hashPrefix = keyHash.slice(0, 8);

  const { data: license, error } = await supabaseAdmin
    .from("licenses")
    .select("id, email, status, machine_id, bound_at")
    .eq("key_hash", keyHash)
    .maybeSingle();

  if (error) {
    console.error("[validate] db error:", error.message);
    return NextResponse.json({ ok: false, reason: "server_error" }, { status: 500 });
  }
  if (!license) {
    console.warn("[validate] not_found hashPrefix=%s — secret rotated or wrong DB?", hashPrefix);
    return NextResponse.json({ ok: false, reason: "not_found" });
  }
  if (license.status !== "active") {
    return NextResponse.json({ ok: false, reason: license.status });
  }

  // Machine binding logic.
  if (!license.machine_id) {
    // First activation — bind this machine.
    const { error: bindErr } = await supabaseAdmin
      .from("licenses")
      .update({
        machine_id: machineId,
        bound_at: new Date().toISOString(),
        last_validated_at: new Date().toISOString(),
      })
      .eq("id", license.id);
    if (bindErr) {
      console.error("[validate] bind failed:", bindErr.message);
      return NextResponse.json({ ok: false, reason: "server_error" }, { status: 500 });
    }
  } else if (license.machine_id !== machineId) {
    return NextResponse.json({ ok: false, reason: "machine_mismatch" });
  } else {
    // Same machine re-validating. Refresh last_validated_at.
    await supabaseAdmin
      .from("licenses")
      .update({ last_validated_at: new Date().toISOString() })
      .eq("id", license.id);
  }

  const expiresAt = new Date(Date.now() + GRACE_DAYS * 24 * 60 * 60 * 1000).toISOString();
  return NextResponse.json({
    ok: true,
    expiresAt,
    email: license.email,
  });
}
