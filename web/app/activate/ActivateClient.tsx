"use client";

// ActivateClient — reads the license key from the URL fragment.
//
// SECURITY: the key lives in the fragment (#key=SLAP-...), not the query
// string. Fragments are kept entirely in the browser — they are never sent
// to the server, never logged by Vercel/CDN/proxy access logs, never appear
// in Referer headers. This is the whole point of the fragment vs. query
// distinction here.
//
// Backward compat: if an older email landed in someone's inbox with the
// legacy `?key=...` query form, we accept that too as a fallback. New emails
// always use the fragment form going forward.

import { useEffect, useState } from "react";
import { AutoActivate } from "@/app/success/AutoActivate";

export function ActivateClient({ fallbackKey }: { fallbackKey: string }) {
  const [key, setKey] = useState<string>(fallbackKey);

  useEffect(() => {
    // Parse #key=... from the fragment. URLSearchParams handles encoding.
    const hash = typeof window !== "undefined" ? window.location.hash : "";
    if (hash.length > 1) {
      const params = new URLSearchParams(hash.slice(1));
      const fromHash = params.get("key");
      if (fromHash) {
        setKey(fromHash);
        // Strip the fragment from the browser URL bar so a screenshot or
        // shoulder-surf doesn't catch the key. The key stays in component
        // state for AutoActivate to use; only the visible URL is scrubbed.
        try {
          history.replaceState(null, "", window.location.pathname);
        } catch {
          /* non-fatal */
        }
      }
    }
  }, []);

  const deepLink = key ? `slapshift://license?key=${encodeURIComponent(key)}` : "";

  return (
    <>
      {deepLink ? <AutoActivate deepLink={deepLink} /> : null}
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
    </>
  );
}
