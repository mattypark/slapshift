# SlapShift — Web

Landing page for SlapShift, the macOS menu-bar app you slap into action.
Built with Next.js 16 (Turbopack) + React 19 + Tailwind CSS 4.

```
slapshift/web/
├── app/
│   ├── Landing.tsx     # single-file landing page (hero + sections + footer)
│   ├── globals.css     # palette + keyframes + base styles
│   ├── layout.tsx      # root layout
│   └── page.tsx        # Next.js entry
└── README.md           # you are here
```

## Run

```bash
npm run dev    # localhost:3000 (Turbopack)
npm run build
npm run start
```

If port 3000 is busy, Next will fall back to 3001.

## Color palette

The whole page reads from CSS variables defined in `app/globals.css:10`.
Warm, low-saturation, paper-feeling. Cream surface + slap-red accent.

### Surfaces

| Token              | Hex       | Use                              |
| ------------------ | --------- | -------------------------------- |
| `--cream`          | `#efe9d3` | Page background                  |
| `--cream-deeper`   | `#e8e1c6` | Subtle band / sunken sections    |
| `--paper`          | `#f6f1de` | Lifted cards                     |
| `--ground`         | `#2a2820` | Dark code/diagram backdrop       |
| `--rule`           | `#c7c2a8` | Hairlines / dividers             |

### Text

| Token        | Hex       | Use                          |
| ------------ | --------- | ---------------------------- |
| `--ink`      | `#0f0f0e` | Primary text                 |
| `--mute`     | `#7a7568` | Secondary text               |
| `--whisper`  | `#a8a293` | Tertiary (timestamps, etc.)  |

### Brand accents

| Token             | Hex         | Use                                    |
| ----------------- | ----------- | -------------------------------------- |
| `--accent`        | `#d34a2f`   | Slap red — emphasis, `<em>`, sun       |
| `--accent-deep`   | `#a13a23`   | Pressed / darker variant               |
| `--sun`           | `#f4b829`   | Highlight pills                        |
| `--sun-glow`      | `#f4b82966` | Soft glow halo (alpha)                 |
| `--hill`          | `#5a7a4a`   | "Current / active" badges, success     |
| `--hill-deep`     | `#3e5a30`   | Darker green                           |

### Scene-only (café + skyline pixel art)

| Token                    | Hex       | Use                          |
| ------------------------ | --------- | ---------------------------- |
| `--cloud`                | `#c7c2a8` | Drifting pixel clouds        |
| `--building-rose`        | `#c8907e` | Foreground skyline buildings |
| `--building-rose-deep`   | `#a66c5c` | Background skyline buildings |
| `--window`               | `#f4d55c` | Lit pixel windows            |
| `--water`                | `#cfc8ac` | Reflection / water hint      |

## Typography

Two fonts, both exposed as CSS variables:

| Variable        | Used for                              |
| --------------- | ------------------------------------- |
| `--font-serif`  | Headlines, italic emphasis            |
| `--font-mono`   | Labels, captions, version strings     |

Helper class: `.font-mono-tracked` — sets `--font-mono` plus
`letter-spacing: 0.02em`. Most UI labels (section dots, footer captions,
button text) use this with `tracking-[0.25em–0.35em]` and `uppercase`.

## Animation keyframes

All animations live in `globals.css` so React stays declarative.

| Keyframe        | Loop                                            | Used by                       |
| --------------- | ----------------------------------------------- | ----------------------------- |
| `walk-ltr`      | `translateX(-20vw → 115vw)`                     | Footer clouds, café walkers   |
| `walk-rtl`      | reverse of `walk-ltr`                           | Right-to-left NPCs            |
| `drive-ltr/rtl` | `-30vw ↔ 125vw`                                 | (Reserved for future cars)    |
| `bob`           | `translateY(0 ↔ -2px)`                          | Idle character bob            |
| `steam`         | rising + fading puff                            | Coffee cups on tables         |
| `barista-pace`  | `translateX(0 → 140px → 0)`                     | Barista behind counter        |
| `npc-order`     | `110vw → 22vw → 110vw`                          | Café NPC order flow           |
| `drink-show`    | fade + scale-in                                 | Drink in NPC's hand           |
| `step-l/step-r` | alternating `translateY` for legs               | NPC walk cycle                |

## Page structure

```
<Landing>
├── <section> hero (h-screen)
│   ├── <CafeBackground>   # café scene + stateful NPC simulation
│   ├── nav + headline + CTA
│   └── <PixelCharacter>   # foreground laptop-slapper
├── <ModesSection>          # 3-card conveyor, cycles through 8 modes
├── <AlsoSection>           # supporting features
├── <NerdySection>          # technical highlights
├── <PriceSection>          # one-time $15.99
├── <FaqSection>            # 8 FAQ accordion
└── <Footer>                # pixel skyline + drifting clouds + credit
```

## Conventions

- All colors go through CSS variables — no hex literals in component code
  except inside the pixel-art SVGs (where `fill="var(--token)"` is standard).
- Pixel art uses `className="pixelated"` to disable anti-aliasing.
- Tailwind arbitrary-value syntax (`bg-[var(--paper)]`, `text-[var(--ink)]`)
  is the standard way to consume tokens in markup.
- All section labels use the `SectionLabel` primitive — just three colored
  dots (accent / sun / hill). No number, no text.

## Credits

Designed and built by [Matthew Park](https://matthewnpark.com).
