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
    const t = setTimeout(() => {
      window.location.href = deepLink;
    }, 400);
    return () => clearTimeout(t);
  }, [deepLink]);

  return null;
}
