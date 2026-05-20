# SlapShift

A macOS menu-bar app that turns a physical slap on your MacBook into a
configured workspace mode: opens apps, quits distractions, launches URLs,
and (optionally) enters a Focus.

Status: **PLANNING** — see `PLAN.md` for the full design + engineering doc.

## Repository layout

```
slapshift/
  PLAN.md              Full plan (office-hours, CEO review, eng review, build phases)
  spike/SlapSpike/     Weekend 1 IOKit probe — verifies accelerometer access
  app/                 (TBD Weekend 2) Xcode project for the macOS app
  web/                 (TBD Weekend 3) Next.js landing + Stripe + license API
  ops/                 (TBD Weekend 4) Notarization + release scripts
```

## Quick start (current state)

You can only run the spike right now:

```bash
cd spike/SlapSpike
swift run SlapSpike
```

See `spike/SlapSpike/README.md` for what to look for.

## Pricing model

$15/month subscription via Stripe. See `PLAN.md` § 3.6 for the license flow.
