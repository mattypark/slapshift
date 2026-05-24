import type { NextConfig } from "next";

// Security headers applied to every response.
//
// Referrer-Policy: strict-origin-when-cross-origin
//   When a buyer clicks any external link from /success?session_id=cs_test_...
//   the default Referer header would leak the full URL (and session_id) to
//   the destination. `strict-origin-when-cross-origin` strips the path +
//   query, sending only the origin. Defense-in-depth alongside the URL
//   scrubber (ScrubUrl) and the fragment-based /activate#key= scheme.
//
// Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
//   Forces HTTPS for two years on slapshift.app + all subdomains. License
//   key material travels over the wire during /api/license/validate calls,
//   so a downgrade attack would be very bad. 2-year max-age + preload is
//   the modern recommendation; only apply once we're confident the apex
//   and every subdomain serves HTTPS — which Vercel does by default.
//
// X-Content-Type-Options: nosniff
//   Prevents MIME-sniffing. Cheap, no downsides. Stops a class of attacks
//   where uploaded or user-controlled content gets re-interpreted by the
//   browser as a different content type than what we served it as.
//
// X-Frame-Options: DENY
//   Stops anyone from embedding the receipt or activation pages in an
//   iframe to phish/clickjack buyers.
const securityHeaders = [
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  {
    key: "Strict-Transport-Security",
    value: "max-age=63072000; includeSubDomains; preload",
  },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options", value: "DENY" },
];

const nextConfig: NextConfig = {
  async headers() {
    return [
      {
        source: "/:path*",
        headers: securityHeaders,
      },
    ];
  },
};

export default nextConfig;
