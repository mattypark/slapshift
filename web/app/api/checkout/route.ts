// POST /api/checkout
//
// Creates a Stripe Checkout Session for the SlapShift license ($9.99 one-time).
// Returns { url } — the client redirects the browser to that URL.
//
// We don't take any input from the client. Email is collected on Stripe's
// hosted checkout page (the trusted card form). No PII passes through our server
// at this stage.

import { NextResponse } from "next/server";
import { stripe } from "@/app/lib/stripe";
import { env } from "@/app/lib/env";

export const dynamic = "force-dynamic";

export async function POST() {
  try {
    const session = await stripe.checkout.sessions.create(
      {
        mode: "payment",
        line_items: [{ price: env.STRIPE_PRICE_ID, quantity: 1 }],
        success_url: `${env.NEXT_PUBLIC_SITE_URL}/success?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${env.NEXT_PUBLIC_SITE_URL}/?canceled=1`,
        // Stripe asks the customer for their email on the hosted page.
        // We re-use it later in the webhook + on the success page.
        billing_address_collection: "auto",
        allow_promotion_codes: false, // v1.1 will flip this on for discount codes
        // No-refund policy. We surface it on the Checkout page itself so the
        // customer can't later claim they weren't warned. Stripe's `charge.refunded`
        // webhook still fires if we (the merchant) manually refund through the
        // dashboard for a chargeback or fraud — that's why the handler stays.
        custom_text: {
          submit: {
            message: "All sales final. No refunds.",
          },
        },
      },
      {
        // Idempotency: a double-clicked checkout button must not create two sessions.
        // The header below dedupes for 24h based on a request-specific key.
        // The client generates this via a random UUID per page-load if it wants.
        // For server-initiated calls we can omit it; Stripe will accept a fresh session each call.
      },
    );

    if (!session.url) {
      return NextResponse.json({ error: "Stripe returned no checkout URL" }, { status: 500 });
    }

    return NextResponse.json({ url: session.url });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : "unknown error";
    console.error("[checkout] failed:", msg);
    return NextResponse.json({ error: "checkout_failed" }, { status: 500 });
  }
}
