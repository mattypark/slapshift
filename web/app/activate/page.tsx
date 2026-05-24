// /activate
//
// Email button target. Reached by buyers who click "Activate SlapShift" in
// the receipt email. We can't put a `slapshift://` href directly in the
// email — Gmail/Outlook strip custom-protocol links. So the email points
// here (HTTPS, allowed) and this page immediately fires the deep link via
// the same client-gesture trick the /success page uses.
//
// SECURITY: license key arrives in the URL fragment (#key=SLAP-...), NOT the
// query string. Fragments stay in the browser and never hit Vercel function
// logs, CDN access logs, or Referer headers. Reading the fragment requires
// a client component (ActivateClient) because fragments aren't visible to
// server-side rendering.
//
// Backward compat: older emails with `?key=...` still work — we forward the
// searchParams value into the client component as a fallback. New emails
// always use the fragment form.

import { ActivateClient } from "./ActivateClient";

export const dynamic = "force-dynamic";

export default async function ActivatePage({
  searchParams,
}: {
  searchParams: Promise<{ key?: string }>;
}) {
  const { key: legacyKey = "" } = await searchParams;

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
        <ActivateClient fallbackKey={legacyKey} />
      </div>
    </main>
  );
}
