// /success — post-checkout landing.
//
// Stripe redirects here with ?session_id=cs_test_... after a successful payment.
// We retrieve the session server-side, pull the license key out of metadata
// (the webhook attached it there after generating + HMAC'ing it), and render
// the key plus a one-click `slapshift://` activation link.
//
// The plaintext key lives in three places only:
//   1) the Resend email we sent the buyer
//   2) the buyer's Mac (Keychain, after activation)
//   3) Stripe session metadata (which this page reads)
// The DB only ever holds the HMAC. If Stripe is unreachable, the buyer can
// always recover the key from the email.
//
// Race condition: Stripe's redirect can beat the webhook by 1-10 seconds. If
// the webhook hasn't populated session.metadata.license_key yet, we render
// a friendly "generating your license…" screen that auto-refreshes every
// 2s for up to MAX_WAIT_SECONDS, then falls back to "check your email."
// Once the key arrives, <AutoActivate> client-fires the slapshift:// deep
// link automatically so the buyer doesn't have to click anything extra.

import Link from "next/link";
import { stripe } from "@/app/lib/stripe";
import { looksLikeKey } from "@/app/lib/license";
import { CopyKeyButton } from "./CopyKeyButton";
import { AutoActivate } from "./AutoActivate";

export const dynamic = "force-dynamic";

type Search = { [key: string]: string | string[] | undefined };

// Maximum seconds to wait for the webhook → metadata update before giving up
// and pointing the buyer at email. Stripe webhooks usually deliver in
// under a second, but cold lambdas + DB writes can push it to 5-10s.
const MAX_WAIT_SECONDS = 20;

export default async function SuccessPage({
  searchParams,
}: {
  searchParams: Promise<Search>;
}) {
  const params = await searchParams;
  const sessionId = typeof params.session_id === "string" ? params.session_id : "";
  // Elapsed seconds tracked across auto-refreshes via the `t` query param.
  // Once we cross MAX_WAIT_SECONDS we stop auto-refreshing and surface
  // the "check your email" fallback instead of looping forever.
  const elapsed = Math.max(0, Number(typeof params.t === "string" ? params.t : "0") || 0);

  if (!sessionId) {
    return <ErrorShell title="Missing session" body="No checkout session was provided. If you just paid, check your email — the license key was sent there." />;
  }

  let key: string | null = null;
  let email: string | null = null;
  let paid = false;

  try {
    const session = await stripe.checkout.sessions.retrieve(sessionId);
    paid = session.payment_status === "paid";
    email = session.customer_details?.email ?? session.customer_email ?? null;
    const maybeKey = session.metadata?.license_key;
    if (typeof maybeKey === "string" && looksLikeKey(maybeKey)) {
      key = maybeKey;
    }
  } catch {
    return <ErrorShell title="Couldn't find that session" body="That checkout session doesn't exist or has expired. Your license key was emailed at the moment of purchase — check there." />;
  }

  // Pending states: payment not yet confirmed OR key not yet minted. For the
  // first MAX_WAIT_SECONDS we render a generating-screen with auto-refresh
  // instead of bouncing the buyer to an error page on a normal webhook delay.
  if (!paid || !key) {
    if (elapsed < MAX_WAIT_SECONDS) {
      return (
        <PendingShell
          sessionId={sessionId}
          elapsed={elapsed}
          title={paid ? "Generating your license…" : "Confirming payment…"}
          body={
            paid
              ? "Payment confirmed. We're minting your license key now — this usually takes a second or two."
              : "Stripe is confirming your payment. Hang tight — this page will update automatically."
          }
        />
      );
    }
    return (
      <ErrorShell
        title={paid ? "Your key has been sent to your email." : "Payment still processing"}
        body={
          paid
            ? "Open the email from licenses@slapshift.app, copy your license key, then open SlapShift and paste it into the license field. Click Activate and you're in."
            : "Stripe hasn't confirmed the payment yet. Refresh in a few seconds — your license key will be emailed the moment payment clears."
        }
      />
    );
  }

  const deepLink = `slapshift://license?key=${encodeURIComponent(key)}`;

  return (
    <main className="min-h-screen bg-[var(--cream,#f4ecdc)] text-[var(--ink,#1a1a1a)] flex items-center justify-center px-6 py-16">
      {/* Auto-fires the slapshift:// deep link 400ms after mount so the buyer
          doesn't have to manually click Activate. Safe in modern browsers as
          a same-origin top-level navigation triggered shortly after a real
          user interaction (the Stripe redirect). Falls back silently if the
          browser blocks it — the button below still works. */}
      <AutoActivate deepLink={deepLink} />
      <div className="max-w-xl w-full">
        <div className="font-mono text-[10px] uppercase tracking-[0.3em] text-neutral-500 mb-6">
          01 · Receipt
        </div>
        <h1
          className="text-5xl md:text-6xl font-serif leading-[1.05] mb-4"
          style={{ fontFamily: "var(--font-serif)" }}
        >
          You bought a slap.
        </h1>
        <p className="font-mono text-sm text-neutral-700 leading-relaxed mb-10">
          {email ? <>Receipt + license key sent to <strong>{email}</strong>. </> : null}
          Opening SlapShift now… If nothing happens, click Activate below or paste the key manually.
        </p>

        <div className="border border-[var(--ink,#1a1a1a)] bg-white/60 p-6 mb-6">
          <div className="font-mono text-[10px] uppercase tracking-[0.3em] text-neutral-500 mb-3">
            License key
          </div>
          <div className="font-mono text-sm md:text-base break-all select-all leading-relaxed mb-4">
            {key}
          </div>
          <CopyKeyButton value={key} />
        </div>

        <a
          href={deepLink}
          className="block w-full text-center bg-[var(--ink,#1a1a1a)] text-[var(--cream,#f4ecdc)] py-4 font-mono text-xs uppercase tracking-[0.25em] hover:bg-[var(--accent,#d8392e)] transition-colors mb-3"
        >
          Activate SlapShift →
        </a>

        <p className="font-mono text-[11px] text-neutral-500 leading-relaxed text-center">
          Don't have the app yet?{" "}
          <Link href="/" className="underline hover:text-[var(--ink,#1a1a1a)]">
            Download the DMG
          </Link>
          , drag it to Applications, then click Activate above.
        </p>
      </div>
    </main>
  );
}

function PendingShell({
  sessionId,
  elapsed,
  title,
  body,
}: {
  sessionId: string;
  elapsed: number;
  title: string;
  body: string;
}) {
  // Each refresh advances `t` by 2 so we naturally bail out of the loop at
  // MAX_WAIT_SECONDS without needing server-side state. Encoding sessionId
  // keeps the loop scoped to this checkout.
  const nextT = elapsed + 2;
  const refreshUrl = `/success?session_id=${encodeURIComponent(sessionId)}&t=${nextT}`;
  return (
    <html lang="en">
      <head>
        {/* The meta refresh is the whole engine — no JS required, no client
            component, works inside iframes and webviews. 2s cadence balances
            "feels responsive" against "don't hammer the Stripe API". */}
        <meta httpEquiv="refresh" content={`2; url=${refreshUrl}`} />
      </head>
      <body>
        <main className="min-h-screen bg-[var(--cream,#f4ecdc)] text-[var(--ink,#1a1a1a)] flex items-center justify-center px-6 py-16">
          <div className="max-w-xl w-full text-center">
            <div className="font-mono text-[10px] uppercase tracking-[0.3em] text-neutral-500 mb-6">
              Working on it
            </div>
            <h1
              className="text-4xl md:text-5xl font-serif leading-[1.05] mb-4"
              style={{ fontFamily: "var(--font-serif)" }}
            >
              {title}
            </h1>
            <p className="font-mono text-sm text-neutral-700 leading-relaxed mb-8">
              {body}
            </p>
            <div
              role="status"
              aria-label="Loading"
              className="inline-block h-6 w-6 animate-spin rounded-full border-2 border-neutral-400 border-t-transparent"
            />
            <p className="font-mono text-[11px] text-neutral-500 leading-relaxed mt-8">
              This page refreshes every couple of seconds. {Math.max(0, MAX_WAIT_SECONDS - elapsed)}s before we fall back to email.
            </p>
          </div>
        </main>
      </body>
    </html>
  );
}

function ErrorShell({ title, body }: { title: string; body: string }) {
  return (
    <main className="min-h-screen bg-[var(--cream,#f4ecdc)] text-[var(--ink,#1a1a1a)] flex items-center justify-center px-6 py-16">
      <div className="max-w-xl w-full text-center">
        <div className="font-mono text-[10px] uppercase tracking-[0.3em] text-neutral-500 mb-6">
          Heads up
        </div>
        <h1
          className="text-4xl md:text-5xl font-serif leading-[1.05] mb-4"
          style={{ fontFamily: "var(--font-serif)" }}
        >
          {title}
        </h1>
        <p className="font-mono text-sm text-neutral-700 leading-relaxed mb-8">
          {body}
        </p>
        <Link
          href="/"
          className="inline-block border border-[var(--ink,#1a1a1a)] px-6 py-3 font-mono text-xs uppercase tracking-[0.25em] hover:bg-[var(--ink,#1a1a1a)] hover:text-[var(--cream,#f4ecdc)] transition-colors"
        >
          ← Back to site
        </Link>
      </div>
    </main>
  );
}
