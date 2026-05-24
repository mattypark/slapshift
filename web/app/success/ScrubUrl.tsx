"use client";

// ScrubUrl — strips session_id from the address bar after first render.
//
// Belt-and-suspenders defense against Finding 2 (Stripe session_id leakage).
// The atomic reveal-once flag in /success/page.tsx is the real protection,
// but scrubbing the URL also prevents:
//   - shoulder-surf of the session_id from the address bar
//   - leaking session_id via Referer if the buyer clicks any external link
//   - the session_id ending up in browser history / autocomplete
//
// We replace with the pathname only — no reload, no navigation, no flash.
// React state is unaffected because the key was already rendered server-side.

import { useEffect } from "react";

export function ScrubUrl() {
  useEffect(() => {
    try {
      if (window.location.search) {
        history.replaceState(null, "", window.location.pathname);
      }
    } catch {
      /* non-fatal */
    }
  }, []);
  return null;
}
