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

import Link from "next/link";
import { stripe } from "@/app/lib/stripe";
import { looksLikeKey } from "@/app/lib/license";
import { CopyKeyButton } from "./CopyKeyButton";

export const dynamic = "force-dynamic";

type Search = { [key: string]: string | string[] | undefined };

export default async function SuccessPage({
  searchParams,
}: {
  searchParams: Promise<Search>;
}) {
  const params = await searchParams;
  const sessionId = typeof params.session_id === "string" ? params.session_id : "";

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

  if (!paid) {
    return <ErrorShell title="Payment still processing" body="Stripe hasn't confirmed the payment yet. Refresh in a few seconds, or check your email — the key will be sent the moment payment clears." />;
  }

  if (!key) {
    return <ErrorShell title="Key not ready yet" body="Payment confirmed, but the license key hasn't been generated yet. This usually takes a second or two — refresh the page. If it persists, email support@slapshift.app." />;
  }

  const deepLink = `slapshift://license?key=${encodeURIComponent(key)}`;

  return (
    <main className="min-h-screen bg-[var(--cream,#f4ecdc)] text-[var(--ink,#1a1a1a)] flex items-center justify-center px-6 py-16">
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
          Your key is below. One click activates the Mac app — or paste it manually if the deep link doesn't fire.
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
