// Stripe client (server-only).
//
// Lazily instantiated: reading STRIPE_SECRET_KEY at module load broke `next build`
// because Next collects page data for /api/webhook before runtime env is available.
// The Proxy below defers `new Stripe(...)` until the first property access at
// request time, which is when env vars are actually populated on Vercel.

import "server-only";
import Stripe from "stripe";
import { env } from "./env";

let instance: Stripe | null = null;

function getStripe(): Stripe {
  if (!instance) {
    instance = new Stripe(env.STRIPE_SECRET_KEY, {
      // Pin to the SDK's bundled version so requests don't change under us
      // when the SDK is upgraded. Bump intentionally after testing.
      apiVersion: "2026-04-22.dahlia",
      appInfo: { name: "SlapShift", version: "0.1.0" },
    });
  }
  return instance;
}

export const stripe = new Proxy({} as Stripe, {
  get(_target, prop) {
    return Reflect.get(getStripe(), prop, getStripe());
  },
});
