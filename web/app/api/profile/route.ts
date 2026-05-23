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

export const dynamic = "force-dynamic";

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

  if (!isValidEmail(emailRaw)) {
    return NextResponse.json({ error: "invalid_email" }, { status: 400 });
  }

  // If "other" was selected, otherDetail must be present. Mirrors the Mac
  // app's canAdvance gate so a tampered client can't slip blank entries in.
  if (usage.includes("other") && otherDetail.length === 0) {
    return NextResponse.json({ error: "other_detail_required" }, { status: 400 });
  }

  const { error } = await supabaseAdmin.from("onboarding_profiles").upsert(
    {
      email: emailRaw,
      name: name || null,
      usage,
      other_detail: otherDetail || null,
      // last_seen_at bumps on every upsert so we can tell "they re-ran
      // onboarding" from "they signed up once and disappeared."
      last_seen_at: new Date().toISOString(),
    },
    { onConflict: "email" },
  );

  if (error) {
    console.error("[profile] upsert failed:", error.message);
    return NextResponse.json({ error: "db_failure" }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}
