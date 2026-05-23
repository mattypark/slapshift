// /api/checkout
//
// Creates a Stripe Checkout Session for the SlapShift license ($9.99 one-time).
//
// Two entry points share the same `createCheckoutSession` core:
//   • POST — used by the landing page's "Buy" button. Returns JSON { url }
//            and the client navigates to it. Keeps PII off our server.
//   • GET  — used by the desktop app. The Mac app calls
//            `NSWorkspace.open("https://slapshift.app/api/checkout?...")`
//            which sends a GET. We create the session and 303-redirect the
//            browser straight to Stripe's hosted page. No JSON dance from
//            inside AppKit.
//
// Optional query params (GET) / unused (POST):
//   email — prefill Stripe's email field so the buyer doesn't retype it
//   promo — show the promotion-code field on the Stripe page so the user's
//           coupon (validated in onboarding) can be redeemed. Stripe verifies
//           the code server-side; we only forward what the buyer typed.

import { NextRequest, NextResponse } from "next/server";
import type Stripe from "stripe";
import { stripe } from "@/app/lib/stripe";
import { env } from "@/app/lib/env";

export const dynamic = "force-dynamic";

type CheckoutOptions = {
  email?: string;
  /// When the buyer applied a promo code in the desktop app, we flip
  /// `allow_promotion_codes` on so they can paste it on the Stripe page.
  /// Stripe enforces validity; we just enable the UI.
  allowPromotionCodes?: boolean;
};

async function createCheckoutSession(opts: CheckoutOptions = {}) {
  const params: Stripe.Checkout.SessionCreateParams = {
    mode: "payment",
    line_items: [{ price: env.STRIPE_PRICE_ID, quantity: 1 }],
    success_url: `${env.NEXT_PUBLIC_SITE_URL}/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${env.NEXT_PUBLIC_SITE_URL}/?canceled=1`,
    billing_address_collection: "auto",
    // Promotion codes always allowed at checkout. Buyers may have a code from
    // a launch DM, Twitter post, or friend referral and need the field visible
    // on the Stripe page regardless of whether they came from the desktop app
    // or the website Buy button.
    allow_promotion_codes: opts.allowPromotionCodes ?? true,
    custom_text: {
      submit: {
        message: "All sales final. No refunds.",
      },
    },
  };

  // Only set customer_email if it looks vaguely sane — Stripe rejects malformed
  // strings with a 400, which would be worse than just not prefilling.
  if (opts.email && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(opts.email)) {
    params.customer_email = opts.email;
  }

  return stripe.checkout.sessions.create(params);
}

export async function POST() {
  try {
    const session = await createCheckoutSession();
    if (!session.url) {
      return NextResponse.json({ error: "Stripe returned no checkout URL" }, { status: 500 });
    }
    return NextResponse.json({ url: session.url });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "unknown error";
    console.error("[checkout] POST failed:", msg);
    return NextResponse.json({ error: "checkout_failed" }, { status: 500 });
  }
}

export async function GET(req: NextRequest) {
  try {
    const email = req.nextUrl.searchParams.get("email") ?? undefined;
    const promo = req.nextUrl.searchParams.get("promo") ?? undefined;
    const session = await createCheckoutSession({
      email,
      allowPromotionCodes: Boolean(promo),
    });
    if (!session.url) {
      // No URL = something is upstream-broken at Stripe. Send the user back
      // to the landing page rather than dumping a JSON error in their browser.
      return NextResponse.redirect(`${env.NEXT_PUBLIC_SITE_URL}/?checkout=failed`, 303);
    }
    // 303 See Other: tells the browser to GET the new location even though
    // we got here via GET — explicit redirect semantics.
    return NextResponse.redirect(session.url, 303);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "unknown error";
    console.error("[checkout] GET failed:", msg);
    return NextResponse.redirect(`${env.NEXT_PUBLIC_SITE_URL}/?checkout=failed`, 303);
  }
}
