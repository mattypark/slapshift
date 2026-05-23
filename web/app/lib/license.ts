// License key generation, formatting, and HMAC hashing.
//
// Format:
//   SLAP-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX  (4-char groups, Crockford base32)
//   - "SLAP" prefix lets us reject obvious typos before hashing
//   - 7 groups of 4 chars = 28 random chars = ~140 bits of entropy
//   - Crockford base32 (no 0/O/1/I/L/U confusion) so users can read it off a screen
//
// Storage:
//   plaintext key  → only Stripe metadata + Resend email + user's machine
//   key_hash       → HMAC-SHA256(plaintext, LICENSE_HMAC_SECRET), hex
//                    stored in Supabase; if DB is leaked, keys aren't usable
//
// Validation flow:
//   user pastes key → app POSTs to /api/license/validate
//   server normalizes (strip dashes, uppercase) → HMACs → looks up by key_hash

import "server-only";
import { createHash, createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import { env } from "./env";

const CROCKFORD = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"; // 32 chars, no O/I/L/U
const GROUPS = 7;
const GROUP_LEN = 4;

export function generateKey(): string {
  const totalChars = GROUPS * GROUP_LEN;
  // Each char carries 5 bits — over-sample bytes and take 5-bit chunks.
  const bytes = randomBytes(Math.ceil((totalChars * 5) / 8));
  let bits = 0;
  let value = 0;
  let out = "";
  for (let i = 0; i < bytes.length && out.length < totalChars; i++) {
    value = (value << 8) | bytes[i];
    bits += 8;
    while (bits >= 5 && out.length < totalChars) {
      bits -= 5;
      out += CROCKFORD[(value >> bits) & 0x1f];
    }
  }
  const groups: string[] = [];
  for (let i = 0; i < GROUPS; i++) {
    groups.push(out.slice(i * GROUP_LEN, (i + 1) * GROUP_LEN));
  }
  return `SLAP-${groups.join("-")}`;
}

/** Normalize user-pasted input: uppercase, strip anything that isn't [A-Z0-9],
 * swap common Crockford lookalikes. We strip aggressively (not just dashes +
 * whitespace) because Gmail/Outlook web clipboards routinely smuggle in
 * zero-width spaces, non-breaking spaces, and en/em-dashes when users copy
 * styled monospace text. Anything that survived `escapeHtml` should be safe
 * to throw away here. */
export function normalizeKey(raw: string): string {
  let s = raw.trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
  // Crockford forgives O/I/L → 0/1/1
  s = s.replace(/O/g, "0").replace(/[IL]/g, "1").replace(/U/g, "V");
  return s;
}

/** Returns true if the raw input matches our format.
 *
 * Important: we cannot use the full `normalizeKey` here because its
 * Crockford lookalike substitution (`[IL] -> 1`) corrupts the literal
 * "SLAP" prefix into "S1AP", which then fails the `startsWith("SLAP")`
 * check and rejects every legitimately-formatted key. So we strip
 * clipboard junk + uppercase, verify the prefix on the raw bytes, then
 * apply Crockford substitutions only to the 28-char body.
 *
 * `normalizeKey` itself is left untouched so that previously-issued
 * licenses (whose `key_hash` was computed off the legacy
 * "S1AP..." normalized form) continue to match in the DB. */
export function looksLikeKey(raw: string): boolean {
  const stripped = raw.trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (stripped.length !== 4 + GROUPS * GROUP_LEN) return false;
  if (!stripped.startsWith("SLAP")) return false;
  const body = stripped
    .slice(4)
    .replace(/O/g, "0")
    .replace(/[IL]/g, "1")
    .replace(/U/g, "V");
  for (const c of body) {
    if (!CROCKFORD.includes(c)) return false;
  }
  return true;
}

/** HMAC the normalized key with the server secret. Hex output. */
export function hashKey(rawOrNormalized: string): string {
  const normalized = normalizeKey(rawOrNormalized);
  return createHmac("sha256", env.LICENSE_HMAC_SECRET).update(normalized).digest("hex");
}

/** Hash an IP for the download_events analytics table (privacy-preserving). */
export function hashIp(ip: string): string {
  return createHash("sha256").update(ip + env.LICENSE_HMAC_SECRET).digest("hex").slice(0, 32);
}

/** Constant-time string equality for things like webhook signatures (Stripe SDK handles its own, this is for our own comparisons). */
export function safeEqual(a: string, b: string): boolean {
  const ab = Buffer.from(a);
  const bb = Buffer.from(b);
  if (ab.length !== bb.length) return false;
  return timingSafeEqual(ab, bb);
}
