// Resend client (server-only).

import "server-only";
import { Resend } from "resend";
import { env } from "./env";

// Lazy: see stripe.ts for the rationale.
let instance: Resend | null = null;

function getResend(): Resend {
  if (!instance) {
    instance = new Resend(env.RESEND_API_KEY);
  }
  return instance;
}

export const resend = new Proxy({} as Resend, {
  get(_target, prop) {
    return Reflect.get(getResend(), prop, getResend());
  },
});

export function licenseEmail(opts: { key: string; deepLink: string }) {
  const { key, deepLink } = opts;
  return {
    subject: "Your SlapShift license key",
    html: `
<!doctype html>
<html>
  <body style="font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 560px; margin: 40px auto; padding: 24px; color: #222;">
    <h1 style="font-size: 22px; margin: 0 0 16px;">Thanks for buying SlapShift.</h1>
    <p style="line-height: 1.5;">Your license key:</p>
    <pre style="background: #f4ecdc; padding: 16px; border-radius: 8px; font-size: 16px; user-select: all;">${escapeHtml(key)}</pre>
    <p style="line-height: 1.5;">
      <a href="${escapeAttr(deepLink)}" style="display: inline-block; background: #d8392e; color: white; padding: 12px 20px; border-radius: 6px; text-decoration: none; font-weight: 600;">
        Activate SlapShift
      </a>
    </p>
    <p style="line-height: 1.5; color: #666; font-size: 14px;">
      Or paste the key into SlapShift &rarr; menu bar icon &rarr; Settings &rarr; License.
    </p>
    <p style="line-height: 1.5; color: #999; font-size: 12px; margin-top: 32px;">
      Save this email. Your key only appears here and on the checkout success page.
      Reply if you need help (you'll get a human).
    </p>
  </body>
</html>`.trim(),
    text:
      `Thanks for buying SlapShift.\n\n` +
      `Your license key:\n${key}\n\n` +
      `Activate: ${deepLink}\n\n` +
      `Or paste the key into SlapShift > Settings > License.\n\n` +
      `Save this email — your key only appears here and on the checkout success page.`,
  };
}

function escapeHtml(s: string) {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
}
function escapeAttr(s: string) {
  return escapeHtml(s);
}
