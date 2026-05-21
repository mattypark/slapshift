// Server-only Supabase client using the service_role key.
//
// CRITICAL: service_role bypasses Row Level Security. It must NEVER be imported
// from a client component or sent to the browser. Use only inside route handlers
// (app/api/*/route.ts) or server-side data fetchers.
//
// Importing this file in a "use client" component will fail at build time because
// SUPABASE_SERVICE_ROLE_KEY is not exposed to the client bundle (no NEXT_PUBLIC_ prefix).

import "server-only";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { env } from "./env";

// Lazy: see stripe.ts for the rationale. `next build` collects page data before
// runtime env is populated; reading env at module load breaks the build.
let instance: SupabaseClient | null = null;

function getClient(): SupabaseClient {
  if (!instance) {
    instance = createClient(
      env.NEXT_PUBLIC_SUPABASE_URL,
      env.SUPABASE_SERVICE_ROLE_KEY,
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      },
    );
  }
  return instance;
}

export const supabaseAdmin = new Proxy({} as SupabaseClient, {
  get(_target, prop) {
    return Reflect.get(getClient(), prop, getClient());
  },
});
