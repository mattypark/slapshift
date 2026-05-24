// POST /api/profile
//
// Captures the onboarding profile (name, email, selected usage tags, and an
// optional "other" free-text answer) from the desktop app and upserts it into
// the Supabase `onboarding_profiles` table. Fired from the Mac app the moment
// the user advances off the usage step — that's the earliest point we have
// name + email + intent, and it lets us reach them with Resend updates even
// if they bail before purchasing.
//
// No auth, no signature. This endpoint is callable from anywhere, by design —
// it's a public mailing-list opt-in surface. Server-side defenses:
//   • Email is validated and lowercased before insert.
//   • Free-text fields are length-capped to keep abuse cheap (no 1MB payloads).
//   • Upsert on (email) so retries / re-runs of onboarding don't pile up rows.
//   • Errors are logged but the client always sees { ok: true } unless the
//     payload is structurally invalid — the desktop app treats this as
//     best-effort and must never block onboarding on it.

import { NextResponse } from "next/server";
import { supabaseAdmin } from "@/app/lib/supabase";
import { checkRateLimit, clientIp } from "@/app/lib/ratelimit";

export const dynamic = "force-dynamic";

// Per-IP cap on onboarding posts. A real user advances through the funnel in
// 4-6 POSTs (usage → source → privacy → slap-test → paywall). 15/min leaves
// generous headroom for retries and double-clicks while killing scripted
// abuse that would otherwise spray fake rows into onboarding_profiles. The
// upsert is keyed on email, so a single email can't bloat the table — but
// without this gate, a cycling-email attacker can.
const RATE_LIMIT = 15;
const RATE_WINDOW_S = 60;

const MAX_NAME = 120;
const MAX_EMAIL = 254;
const MAX_OTHER = 500;
const ALLOWED_USAGE = new Set([
  "coding",
  "school",
  "writing",
  "designing",
  "research",
  "other",
]);
// Mirrors SourceStep.options in the Mac app. Keep the two in sync — a
// tampered client can send arbitrary strings, so the server is the source
// of truth for what we accept into Supabase.
const ALLOWED_SOURCE = new Set([
  "google",
  "reddit",
  "twitter",
  "youtube",
  "tiktok",
  "instagram",
  "producthunt",
  "friend",
  "newsletter",
  "other",
]);
// Sanity bounds on the calibration peak. Anything outside this range is
// either a sensor glitch or a tampered payload — clamp/reject rather than
// pollute Supabase with absurd values used to skew future threshold tuning.
const CALIBRATION_MIN_G = 0;
const CALIBRATION_MAX_G = 20;

// Same shape the Mac app validates against — keep them in sync so we don't
// reject legitimate users for trivial differences. RFC 5322 is overkill;
// this catches obvious typos and that's the goal at this layer.
function isValidEmail(email: string): boolean {
  if (email.length < 5 || email.length > MAX_EMAIL) return false;
  if (/\s/.test(email)) return false;
  const at = email.indexOf("@");
  if (at <= 0 || at === email.length - 1) return false;
  const domain = email.slice(at + 1);
  if (!domain.includes(".")) return false;
  if (domain.startsWith(".") || domain.endsWith(".")) return false;
  return true;
}

export async function POST(req: Request) {
  const ip = clientIp(req);
  const rl = await checkRateLimit({
    ip,
    endpoint: "profile",
    limit: RATE_LIMIT,
    windowSeconds: RATE_WINDOW_S,
  });
  if (!rl.ok) {
    return NextResponse.json({ error: "rate_limited" }, { status: 429 });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "invalid_json" }, { status: 400 });
  }

  if (typeof body !== "object" || body === null) {
    return NextResponse.json({ error: "invalid_body" }, { status: 400 });
  }

  const raw = body as Record<string, unknown>;
  const name = typeof raw.name === "string" ? raw.name.trim().slice(0, MAX_NAME) : "";
  const emailRaw = typeof raw.email === "string" ? raw.email.trim().toLowerCase() : "";
  const usage = Array.isArray(raw.usage)
    ? raw.usage.filter((u): u is string => typeof u === "string" && ALLOWED_USAGE.has(u))
    : [];
  const otherDetail =
    typeof raw.otherDetail === "string" ? raw.otherDetail.trim().slice(0, MAX_OTHER) : "";

  // Optional fields — only persisted if the client included them in the
  // payload. The Mac app POSTs after .usage, .source, .privacy, and
  // .slapTest, each adding one new field. Skipping the column on the
  // upsert when the field is absent prevents an earlier POST from blowing
  // away a value collected on a later step.
  // Source step is multi-select. Accept `referralSources` as an array of
  // allow-listed strings and persist as a comma-joined value in the existing
  // `referral_source` text column (schema-stable). For backward compat with
  // any older client that POSTs the singular string, fold it into the same
  // pipeline before validation.
  const rawSources: unknown[] = Array.isArray(raw.referralSources)
    ? raw.referralSources
    : typeof raw.referralSource === "string"
      ? [raw.referralSource]
      : [];
  const referralSourcesList = Array.from(
    new Set(
      rawSources.filter(
        (s): s is string => typeof s === "string" && ALLOWED_SOURCE.has(s),
      ),
    ),
  );
  const referralSource =
    referralSourcesList.length > 0 ? referralSourcesList.join(",") : undefined;
  const telemetryOptIn = typeof raw.telemetryOptIn === "boolean" ? raw.telemetryOptIn : undefined;
  const calibrationPeakG =
    typeof raw.calibrationPeakG === "number" &&
    Number.isFinite(raw.calibrationPeakG) &&
    raw.calibrationPeakG >= CALIBRATION_MIN_G &&
    raw.calibrationPeakG <= CALIBRATION_MAX_G
      ? raw.calibrationPeakG
      : undefined;

  if (!isValidEmail(emailRaw)) {
    return NextResponse.json({ error: "invalid_email" }, { status: 400 });
  }

  // If "other" was selected, otherDetail must be present. Mirrors the Mac
  // app's canAdvance gate so a tampered client can't slip blank entries in.
  if (usage.includes("other") && otherDetail.length === 0) {
    return NextResponse.json({ error: "other_detail_required" }, { status: 400 });
  }

  const upsertRow: Record<string, unknown> = {
    email: emailRaw,
    name: name || null,
    usage,
    other_detail: otherDetail || null,
    // last_seen_at bumps on every upsert so we can tell "they re-ran
    // onboarding" from "they signed up once and disappeared."
    last_seen_at: new Date().toISOString(),
  };
  if (referralSource !== undefined) upsertRow.referral_source = referralSource;
  if (telemetryOptIn !== undefined) upsertRow.telemetry_opt_in = telemetryOptIn;
  if (calibrationPeakG !== undefined) upsertRow.calibration_peak_g = calibrationPeakG;

  const { error } = await supabaseAdmin.from("onboarding_profiles").upsert(
    upsertRow,
    { onConflict: "email" },
  );

  if (error) {
    console.error("[profile] upsert failed:", error.message);
    return NextResponse.json({ error: "db_failure" }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}
