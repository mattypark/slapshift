// Stripe client (server-only).

import "server-only";
import Stripe from "stripe";
import { env } from "./env";

export const stripe = new Stripe(env.STRIPE_SECRET_KEY, {
  // Pin to the SDK's bundled version so requests don't change under us
  // when the SDK is upgraded. Bump intentionally after testing.
  apiVersion: "2026-04-22.dahlia",
  appInfo: { name: "SlapShift", version: "0.1.0" },
});
