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
  // Absolute URL for the logo — Gmail and most clients refuse cid: inline
  // attachments in transactional templates, so we serve the PNG from the
  // marketing site instead. SITE_URL is required at boot via env.ts.
  const logo = `${env.NEXT_PUBLIC_SITE_URL.replace(/\/$/, "")}/SlapshiftS.png`;
  return {
    subject: "Your SlapShift license key",
    html: `
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Your SlapShift license</title>
  </head>
  <body style="margin:0;padding:0;background:#f4ecdc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;color:#1a1a1a;">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#f4ecdc;padding:40px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="560" style="max-width:560px;width:100%;background:#fbf6e8;border:1px solid #1a1a1a;border-radius:4px;overflow:hidden;">
            <!-- Header band: logo + brand name -->
            <tr>
              <td style="padding:32px 32px 20px 32px;border-bottom:1px solid rgba(26,26,26,0.12);">
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
                  <tr>
                    <td style="vertical-align:middle;">
                      <img src="${escapeAttr(logo)}" width="40" height="40" alt="SlapShift" style="display:block;border-radius:8px;">
                    </td>
                    <td style="vertical-align:middle;padding-left:12px;">
                      <div style="font-family:'Iowan Old Style',Georgia,serif;font-size:18px;font-weight:700;letter-spacing:-0.01em;color:#1a1a1a;">
                        SlapShift
                      </div>
                      <div style="font-family:ui-monospace,'SFMono-Regular',Menlo,monospace;font-size:10px;text-transform:uppercase;letter-spacing:0.3em;color:#6b6b6b;margin-top:2px;">
                        License · receipt
                      </div>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>

            <!-- Big headline -->
            <tr>
              <td style="padding:32px 32px 8px 32px;">
                <h1 style="margin:0;font-family:'Iowan Old Style',Georgia,serif;font-size:32px;line-height:1.1;font-weight:700;color:#1a1a1a;">
                  Thanks for buying SlapShift.
                </h1>
              </td>
            </tr>
            <tr>
              <td style="padding:0 32px 24px 32px;">
                <p style="margin:0;font-size:14px;line-height:1.6;color:#444;">
                  Below is your license key. Click <strong>Activate SlapShift</strong> to open the app and unlock it instantly, or paste the key in by hand.
                </p>
              </td>
            </tr>

            <!-- License card -->
            <tr>
              <td style="padding:0 32px 24px 32px;">
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#f4ecdc;border:1px dashed rgba(26,26,26,0.35);border-radius:6px;">
                  <tr>
                    <td style="padding:18px 20px;">
                      <div style="font-family:ui-monospace,'SFMono-Regular',Menlo,monospace;font-size:10px;text-transform:uppercase;letter-spacing:0.3em;color:#6b6b6b;margin-bottom:8px;">
                        License key
                      </div>
                      <div style="font-family:ui-monospace,'SFMono-Regular',Menlo,monospace;font-size:16px;font-weight:600;letter-spacing:0.04em;color:#1a1a1a;word-break:break-all;user-select:all;">
                        ${escapeHtml(key)}
                      </div>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>

            <!-- CTA -->
            <tr>
              <td align="center" style="padding:0 32px 24px 32px;">
                <a href="${escapeAttr(deepLink)}" style="display:inline-block;background:#1a1a1a;color:#f4ecdc;padding:14px 28px;font-family:ui-monospace,'SFMono-Regular',Menlo,monospace;font-size:12px;text-transform:uppercase;letter-spacing:0.25em;text-decoration:none;border-radius:4px;">
                  Activate SlapShift &rarr;
                </a>
              </td>
            </tr>

            <!-- Fine print -->
            <tr>
              <td style="padding:0 32px 24px 32px;">
                <p style="margin:0;font-size:13px;line-height:1.6;color:#555;">
                  Or paste the key into SlapShift &rarr; menu bar icon &rarr; Settings &rarr; License.
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:0 32px 32px 32px;border-top:1px solid rgba(26,26,26,0.10);">
                <p style="margin:20px 0 0 0;font-size:11px;line-height:1.6;color:#888;">
                  Save this email. Your key only appears here and on the checkout success page.
                  Reply if you need help — you'll get a human.
                </p>
              </td>
            </tr>
          </table>

          <!-- Sub-footer -->
          <div style="margin-top:16px;font-family:ui-monospace,'SFMono-Regular',Menlo,monospace;font-size:10px;text-transform:uppercase;letter-spacing:0.3em;color:#8a8a8a;">
            slapshift.app
          </div>
        </td>
      </tr>
    </table>
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
