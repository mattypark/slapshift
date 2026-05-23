// /activate?key=SLAP-XXXX-...
//
// Email button target. Reached by buyers who click "Activate SlapShift" in
// the receipt email. We can't put a `slapshift://` href directly in the
// email — Gmail/Outlook strip custom-protocol links. So the email points
// here (HTTPS, allowed) and this page immediately fires the deep link via
// the same client-gesture trick the /success page uses.
//
// We also show the key + a manual paste fallback so the buyer is never
// stranded if their browser blocks the protocol handoff.

import { AutoActivate } from "@/app/success/AutoActivate";

export const dynamic = "force-dynamic";

export default async function ActivatePage({
  searchParams,
}: {
  searchParams: Promise<{ key?: string }>;
}) {
  const { key = "" } = await searchParams;
  const deepLink = key ? `slapshift://license?key=${encodeURIComponent(key)}` : "";

  return (
    <main
      style={{
        minHeight: "100vh",
        background: "#f4ecdc",
        color: "#1a1a1a",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: "40px 16px",
        fontFamily:
          "-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif",
      }}
    >
      {deepLink ? <AutoActivate deepLink={deepLink} /> : null}
      <div
        style={{
          maxWidth: 480,
          width: "100%",
          background: "#fbf6e8",
          border: "1px solid #1a1a1a",
          borderRadius: 4,
          padding: 32,
          textAlign: "center",
        }}
      >
        <h1
          style={{
            margin: 0,
            fontFamily: "'Iowan Old Style',Georgia,serif",
            fontSize: 28,
            lineHeight: 1.1,
            fontWeight: 700,
          }}
        >
          Opening SlapShift…
        </h1>
        <p style={{ marginTop: 16, fontSize: 14, lineHeight: 1.6, color: "#444" }}>
          If macOS asks &ldquo;Open SlapShift?&rdquo;, click <strong>Open</strong>. If
          nothing happens in a few seconds, click the button below.
        </p>

        {key ? (
          <>
            <a
              href={deepLink}
              style={{
                display: "inline-block",
                marginTop: 20,
                background: "#1a1a1a",
                color: "#f4ecdc",
                padding: "14px 28px",
                fontFamily: "ui-monospace,'SFMono-Regular',Menlo,monospace",
                fontSize: 12,
                textTransform: "uppercase",
                letterSpacing: "0.25em",
                textDecoration: "none",
                borderRadius: 4,
              }}
            >
              Activate SlapShift &rarr;
            </a>

            <div
              style={{
                marginTop: 28,
                padding: "16px 20px",
                background: "#f4ecdc",
                border: "1px dashed rgba(26,26,26,0.35)",
                borderRadius: 6,
                textAlign: "left",
              }}
            >
              <div
                style={{
                  fontFamily: "ui-monospace,'SFMono-Regular',Menlo,monospace",
                  fontSize: 10,
                  textTransform: "uppercase",
                  letterSpacing: "0.3em",
                  color: "#6b6b6b",
                  marginBottom: 8,
                }}
              >
                Or paste this key into SlapShift
              </div>
              <div
                style={{
                  fontFamily: "ui-monospace,'SFMono-Regular',Menlo,monospace",
                  fontSize: 14,
                  fontWeight: 600,
                  userSelect: "all",
                  wordBreak: "break-all",
                }}
              >
                {key}
              </div>
            </div>
          </>
        ) : (
          <p style={{ marginTop: 20, fontSize: 13, color: "#a33" }}>
            Missing license key. Check your receipt email for the activation link.
          </p>
        )}
      </div>
    </main>
  );
}
