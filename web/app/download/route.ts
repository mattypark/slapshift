// GET /download
//
// Redirects to the actual hosted DMG (GitHub Releases, R2, Blob, etc).
// Buyers see "slapshift.app/download" in their URL bar for the brief
// moment between click and file save — they never see the underlying
// host in the link itself. The DMG URL stays out of the browser bundle.

import { NextResponse } from "next/server";
import { env } from "@/app/lib/env";

export const dynamic = "force-dynamic";

export async function GET() {
  // 302 (temporary) rather than 301 — if we ever change hosts, browsers
  // and CDNs won't cache the old target.
  return NextResponse.redirect(env.DMG_URL, 302);
}
