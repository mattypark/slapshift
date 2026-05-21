"use client";

// Tiny client island for the copy-to-clipboard interaction.
// Lives next to the success page so the page itself can stay a Server Component
// (it needs to call Stripe with the secret key — that can't ship to the browser).

import { useState } from "react";

export function CopyKeyButton({ value }: { value: string }) {
  const [copied, setCopied] = useState(false);

  async function onCopy() {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
      setTimeout(() => setCopied(false), 1800);
    } catch {
      // Clipboard API can fail in some embedded webviews. Fall back to a select.
      const sel = window.getSelection();
      const range = document.createRange();
      const el = document.createElement("span");
      el.textContent = value;
      document.body.appendChild(el);
      range.selectNodeContents(el);
      sel?.removeAllRanges();
      sel?.addRange(range);
    }
  }

  return (
    <button
      type="button"
      onClick={onCopy}
      className="font-mono text-[11px] uppercase tracking-[0.25em] text-neutral-600 hover:text-[var(--accent,#d8392e)] transition-colors"
    >
      {copied ? "✓ Copied" : "Copy to clipboard"}
    </button>
  );
}
