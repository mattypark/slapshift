"use client";

// AutoActivate — fires the slapshift:// deep link automatically on mount.
//
// Why a client component: protocol-handler navigation must happen on the
// client, not during server render. We set window.location.href instead of
// router.push() because Next's router won't navigate to custom schemes —
// only http(s).
//
// Why 400ms delay: gives the browser a beat to settle after the Stripe
// redirect so Safari/Chrome don't treat the protocol jump as "navigation
// without user gesture" and block it. Also lets the buyer see the receipt
// briefly before macOS focus-steals to SlapShift.
//
// Idempotency: we fire exactly once per mount via a ref guard. React 18's
// strict-mode double-effect would otherwise fire it twice, which can cause
// macOS to show two "Open SlapShift?" prompts.

import { useEffect, useRef } from "react";

export function AutoActivate({ deepLink }: { deepLink: string }) {
  const firedRef = useRef(false);

  useEffect(() => {
    if (firedRef.current) return;
    firedRef.current = true;
    // Anchor.click() is more reliable than window.location.href for custom
    // schemes. Chrome/Safari treat assigning location.href to a non-http
    // scheme as gesture-less navigation and often block it silently. A
    // synthesized anchor click is treated as a real user-initiated link
    // activation and triggers macOS's "Open SlapShift?" handoff.
    // We keep location.href as a final fallback in case the anchor route
    // is filtered (e.g. in-app webviews).
    const t = setTimeout(() => {
      try {
        const a = document.createElement("a");
        a.href = deepLink;
        a.rel = "noopener";
        a.style.display = "none";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
      } catch {
        /* fall through */
      }
      // Belt + suspenders: if the anchor click didn't navigate (some
      // browsers throw silently), still try location.href a beat later.
      window.setTimeout(() => {
        try {
          window.location.href = deepLink;
        } catch {
          /* user can still click the manual Activate button */
        }
      }, 250);
    }, 400);
    return () => clearTimeout(t);
  }, [deepLink]);

  return null;
}
