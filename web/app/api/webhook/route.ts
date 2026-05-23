// POST /api/webhook
//
// Stripe webhook handler. Receives async events from Stripe (payment success,
// refund, dispute, etc). Currently wired for:
//
//   checkout.session.completed  → generate a license key, store the HMAC,
//                                  attach plaintext to Stripe metadata, email
//                                  the customer via Resend.
//   charge.refunded             → mark the license status='refunded'.
//
// SECURITY: signature verification is non-negotiable. Without it, any internet
// attacker could POST a fake `checkout.session.completed` and mint themselves a
// free license. The signature is in the `stripe-signature` header and is
// verified against STRIPE_WEBHOOK_SECRET.

import { NextResponse } from "next/server";
import type Stripe from "stripe";
import { stripe } from "@/app/lib/stripe";
import { supabaseAdmin } from "@/app/lib/supabase";
import { resend, licenseEmail } from "@/app/lib/resend";
import { generateKey, hashKey } from "@/app/lib/license";
import { env } from "@/app/lib/env";

export const dynamic = "force-dynamic";

export async function POST(req: Request) {
  const sig = req.headers.get("stripe-signature");
  if (!sig) {
    return NextResponse.json({ error: "missing_signature" }, { status: 400 });
  }

  // Stripe needs the raw request body (string) to verify the signature.
  // Do NOT JSON.parse first.
  const raw = await req.text();

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(raw, sig, env.STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    const msg = err instanceof Error ? err.message : "invalid";
    console.warn("[webhook] signature verification failed:", msg);
    return NextResponse.json({ error: "invalid_signature" }, { status: 400 });
  }

  try {
    switch (event.type) {
      case "checkout.session.completed":
        await handleCheckoutCompleted(event.data.object);
        break;
      case "charge.refunded":
        await handleChargeRefunded(event.data.object);
        break;
      default:
        // Ignore events we don't care about. Stripe retries on non-2xx, so we 200.
        break;
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : "unknown";
    console.error(`[webhook] handler for ${event.type} failed:`, msg);
    // Return 500 so Stripe retries. Idempotency is enforced by the DB unique
    // constraint on stripe_session_id, so a retry can't double-issue a license.
    return NextResponse.json({ error: "handler_failed" }, { status: 500 });
  }

  return NextResponse.json({ received: true });
}

async function handleCheckoutCompleted(session: Stripe.Checkout.Session) {
  const email = session.customer_details?.email ?? session.customer_email;
  if (!email) {
    throw new Error(`session ${session.id} has no email`);
  }

  // Idempotency check — if we already issued a key for this session, do nothing.
  // (Stripe occasionally re-sends checkout.session.completed.)
  const { data: existing } = await supabaseAdmin
    .from("licenses")
    .select("id")
    .eq("stripe_session_id", session.id)
    .maybeSingle();
  if (existing) {
    console.log(`[webhook] license already exists for session ${session.id}, skipping`);
    return;
  }

  const key = generateKey();
  const keyHash = hashKey(key);

  // Insert license row. Unique constraint on stripe_session_id catches
  // any race condition (two concurrent webhook deliveries).
  const { error: insertErr } = await supabaseAdmin.from("licenses").insert({
    email,
    key_hash: keyHash,
    stripe_session_id: session.id,
    stripe_customer_id: typeof session.customer === "string" ? session.customer : null,
    status: "active",
  });
  if (insertErr) {
    // If it's a uniqueness violation, another concurrent webhook won the race — that's fine.
    if (insertErr.code === "23505") {
      console.log(`[webhook] race: license for session ${session.id} already inserted`);
      return;
    }
    throw new Error(`supabase insert failed: ${insertErr.message}`);
  }

  // Attach plaintext key to the Stripe session metadata so the /success page
  // can show it to the customer (in case the email is slow/lost). Stripe
  // metadata is private to your account and won't leak.
  try {
    await stripe.checkout.sessions.update(session.id, {
      metadata: { ...(session.metadata ?? {}), license_key: key },
    });
  } catch (err) {
    // Non-fatal: customer still gets the email. Log and move on.
    console.warn(`[webhook] failed to attach metadata to session ${session.id}:`, err);
  }

  // Email the customer.
  // Use an HTTPS redirect page in the email instead of a raw `slapshift://`
  // URL: Gmail (and most webmail clients) silently strip or de-link custom
  // protocol hrefs as a security measure, so the button would do nothing.
  // The /activate page fires the deep link client-side once we're back in
  // browser context, which works because it's a user-gesture navigation.
  const siteUrl = env.NEXT_PUBLIC_SITE_URL.replace(/\/$/, "");
  const deepLink = `${siteUrl}/activate?key=${encodeURIComponent(key)}`;
  try {
    await resend.emails.send({
      from: env.RESEND_FROM_EMAIL,
      to: email,
      ...licenseEmail({ key, deepLink }),
    });
  } catch (err) {
    // Logged but not thrown — the user can still recover the key from the success page.
    console.error(`[webhook] resend.send failed for ${email}:`, err);
  }
}

async function handleChargeRefunded(charge: Stripe.Charge) {
  // Find the license via the linked Checkout Session.
  // charge.payment_intent → list sessions for that PI → mark its license refunded.
  const piId = typeof charge.payment_intent === "string" ? charge.payment_intent : charge.payment_intent?.id;
  if (!piId) return;

  const sessions = await stripe.checkout.sessions.list({ payment_intent: piId, limit: 1 });
  const session = sessions.data[0];
  if (!session) {
    console.warn(`[webhook] charge.refunded: no session for payment_intent ${piId}`);
    return;
  }

  const { error } = await supabaseAdmin
    .from("licenses")
    .update({ status: "refunded" })
    .eq("stripe_session_id", session.id);
  if (error) {
    throw new Error(`mark refunded failed: ${error.message}`);
  }
}
