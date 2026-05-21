"use client";

import { useEffect, useRef, useState } from "react";

// =============================================================================
// SlapShift landing — single café scene.
//
// Hero copy + Download DMG button sit centered over a static café background.
// Character sits in the middle-bottom on a café chair and slaps the MacBook
// every 3 seconds. Below the hero is a placeholder section where the next
// (vertical) scroll content will go.
// =============================================================================

export default function Landing() {
  return (
    <>
      <section className="relative h-screen overflow-hidden">
        <CafeBackground />

        {/* Top nav — logo only, anchored top-left */}
        <div className="absolute top-0 left-0 z-50 px-[22px] py-[14px]">
          <a href="#" className="inline-flex items-center" aria-label="SlapShift">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src="/realslapshift.png"
              alt="SlapShift"
              className="h-20 md:h-55 w-auto pixelated"
            />
          </a>
        </div>

        {/* Hero copy — centered vertically, nudged 10px below true center */}
        <div className="relative z-20 flex h-full items-center justify-center px-8">
          <div className="text-center max-w-4xl mt-[10px]">
            <h1
              className="text-6xl md:text-8xl font-serif leading-[1.02] tracking-tight text-[var(--ink)]"
              style={{ fontFamily: "var(--font-serif)" }}
            >
              Slap your <em className="text-[var(--accent)]">Mac</em>,
              <br />
              workflow <em className="text-[var(--accent)]">maxed</em>.
            </h1>
            <p className="font-mono-tracked text-sm md:text-base text-[var(--mute)] mt-8 max-w-md mx-auto leading-relaxed">
              A macOS launcher you slap into action. One gesture rewrites your
              whole workspace.
            </p>

            <div className="mt-10 flex flex-col items-center gap-3 pointer-events-auto">
              <a
                href="/downloads/SlapShift-0.1.0.dmg"
                className="group inline-flex items-center gap-3 bg-[var(--ink)] text-[var(--cream)] px-7 py-3.5 font-mono-tracked text-xs uppercase tracking-[0.25em] hover:bg-[var(--accent)] transition-colors"
              >
                <DownloadIcon />
                <span>Download for macOS</span>
              </a>
              <div className="font-mono-tracked text-[10px] uppercase tracking-[0.3em] text-[var(--mute)]">
                v0.1.0 · 4.2 MB · Apple Silicon · Updated May 2026
              </div>
            </div>
          </div>
        </div>

        {/* Character — fixed center-bottom on café chair, slaps every 3s */}
        <PixelCharacter />
      </section>

      {/* ============================================================
          VERTICAL CONTENT.
          Content/copy inspired by slapmac.com, design entirely our own.
          Alternating left/center/right alignment — NOT a card stack.
          ============================================================ */}

      <ModesSection />
      <AlsoSection />
      <NerdySection />
      <PriceSection />
      <FaqSection />
      <Footer />
    </>
  );
}

// =============================================================================
// Section primitives
// =============================================================================

function SectionLabel({
  num,
  text,
  align = "left",
}: {
  num: string;
  text: string;
  align?: "left" | "center" | "right";
}) {
  const justify =
    align === "center"
      ? "justify-center"
      : align === "right"
        ? "justify-end"
        : "justify-start";
  return (
    <div className={`flex items-center ${justify} mb-6`}>
      <div className="flex gap-[3px]">
        <div className="w-[3px] h-[3px] bg-[var(--accent)]" />
        <div className="w-[3px] h-[3px] bg-[var(--sun)]" />
        <div className="w-[3px] h-[3px] bg-[var(--hill)]" />
      </div>
    </div>
  );
}

function SectionRule() {
  return (
    <div className="max-w-6xl mx-auto px-8">
      <div className="h-px bg-[var(--rule)]" />
    </div>
  );
}

// =============================================================================
// 02 — Modes. Three customizable slots. Left slot rotates through example
// modes every 5s (Studying, Reading, Ideation, Wind down, Workout, Custom...)
// to make clear that any slap-count can hold any mode. Middle and right
// slots show the two ship-with defaults (Coding @ 2 slaps, Apply @ 3 slaps).
// =============================================================================

type Mode = {
  slaps: number;
  name: string;
  tag: string;
  opens: string[];
  quits: string[];
  focus: string;
  color: string;
};

// Conveyor pool — every mode visible in the rotation. Three cards on
// screen at a time; on each tick a new card slides in from the left,
// the existing trio shifts right by one slot, the rightmost card exits
// off the right edge. Order here matters for the cycle.
const MODE_POOL: Mode[] = [
  {
    slaps: 2,
    name: "Coding",
    tag: "Heads-down",
    opens: ["VS Code", "Terminal", "Chrome → localhost:3000"],
    quits: ["Slack", "Discord", "Messages"],
    focus: "Do Not Disturb",
    color: "var(--sun)",
  },
  {
    slaps: 3,
    name: "Apply",
    tag: "Get it sent",
    opens: ["Chrome → Common App", "5 portal tabs", "Notes"],
    quits: ["Spotify", "Twitter"],
    focus: "Personal focus",
    color: "var(--hill)",
  },
  {
    slaps: 1,
    name: "Reading",
    tag: "Slow down",
    opens: ["Kindle", "Reader", "Spotify → lo-fi"],
    quits: ["Slack", "Mail"],
    focus: "Reading focus",
    color: "var(--accent)",
  },
  {
    slaps: 1,
    name: "Studying",
    tag: "Locked in",
    opens: ["Notion", "Anki", "PDF reader"],
    quits: ["Twitter", "Discord"],
    focus: "Study focus",
    color: "var(--accent)",
  },
  {
    slaps: 1,
    name: "Ideation",
    tag: "Open canvas",
    opens: ["Figma", "Obsidian", "Mural"],
    quits: ["Inbox", "Calendar"],
    focus: "Personal focus",
    color: "var(--accent)",
  },
  {
    slaps: 1,
    name: "Wind down",
    tag: "Log off",
    opens: ["Spotify", "Notes"],
    quits: ["Everything else"],
    focus: "Sleep focus",
    color: "var(--accent)",
  },
  {
    slaps: 1,
    name: "Workout",
    tag: "Move",
    opens: ["Spotify → hype", "Strong"],
    quits: ["Slack", "Mail"],
    focus: "Fitness focus",
    color: "var(--accent)",
  },
  {
    slaps: 1,
    name: "Yours",
    tag: "Build it",
    opens: ["+ any app", "+ any URL"],
    quits: ["− any distraction"],
    focus: "Your focus",
    color: "var(--accent)",
  },
];

function ModesSection() {
  return (
    <section className="bg-[var(--cream)] py-24">
      <div className="max-w-6xl mx-auto px-8">
        <SectionLabel num="02" text="Modes" />
        <div className="grid md:grid-cols-12 gap-8 mb-14">
          <div className="md:col-span-7">
            <h2
              className="text-4xl md:text-6xl font-serif text-[var(--ink)] leading-[1.02]"
              style={{ fontFamily: "var(--font-serif)" }}
            >
              Three slots.
              <br />
              <em>Make them anything.</em>
            </h2>
          </div>
          <div className="md:col-span-5 md:pt-6">
            <p className="font-mono-tracked text-sm text-[var(--mute)] leading-relaxed">
              Each slap count is a slot you fill — apps, URLs, Focus modes,
              anything. We ship a couple defaults to get you started. Real
              users wire it for coding, applying, studying, reading,
              ideation, wind-down, workouts — whatever they slap into. Below
              is a snapshot, cycling.
            </p>
          </div>
        </div>

        <ConveyorModes pool={MODE_POOL} />
      </div>
    </section>
  );
}

// =============================================================================
// ConveyorModes — three cards on screen at a time. Every CYCLE_MS:
//
//   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
//   │ incoming │  │  slot 0  │  │  slot 1  │  │  slot 2  │   (idle)
//   └──────────┘  └──────────┘  └──────────┘  └──────────┘
//        ↓             ↓             ↓             ↓
//   (off-screen)    visible      visible       visible
//
//                ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
//                │ incoming │  │  slot 0  │  │  slot 1  │  │  slot 2  │  (shift)
//                └──────────┘  └──────────┘  └──────────┘  └──────────┘
//                  visible      visible       visible    (off-screen)
//
// After the shift settles, the queue rotates: the entering card becomes
// the new slot 0, the previous slot 2 unmounts, and a fresh card is
// pushed onto the front of the queue ready to ride in next cycle. Each
// card animates between its idle and shifting `left` value with a single
// CSS transition — fewer moving parts than a transform-based carousel
// and the browser handles all the interpolation.
// =============================================================================

const CYCLE_MS = 4500; // dwell between shifts
const SHIFT_MS = 720; // duration of the slide

type ConveyorCard = { id: number; mode: Mode; slaps: number };

function ConveyorModes({ pool }: { pool: Mode[] }) {
  // Track the queue as an explicit array of 4 cards: index 0 is the
  // pre-rendered "incoming" card waiting off-screen left, indices 1-3
  // are the three visible cards left-to-right.
  //
  // Slap-count invariant: the three on-screen cards always show
  // {1, 2, 3} in some order — never duplicates. Cards carry their
  // slap count independently of the mode pool. When a card slides
  // in, it inherits the slap count of the card about to slide off,
  // so the dropped count is reintroduced on the left and the visible
  // set remains a permutation of {1,2,3}.
  const idRef = useRef(0);
  const poolIdxRef = useRef(0);
  const makeCard = (mode: Mode, slaps: number): ConveyorCard => ({
    id: idRef.current++,
    mode,
    slaps,
  });
  const nextFromPool = (slaps: number): ConveyorCard => {
    const m = pool[poolIdxRef.current % pool.length];
    poolIdxRef.current += 1;
    return makeCard(m, slaps);
  };

  const [cards, setCards] = useState<ConveyorCard[]>(() => {
    // Seed visible (indices 1,2,3) with a permutation of {1,2,3};
    // incoming (index 0) mirrors index 3's count so the invariant
    // also holds after the first shift.
    poolIdxRef.current = 4;
    const visiblePerm = [2, 3, 1]; // slot 0, slot 1, slot 2
    return [
      makeCard(pool[0], visiblePerm[2]),
      makeCard(pool[1], visiblePerm[0]),
      makeCard(pool[2], visiblePerm[1]),
      makeCard(pool[3], visiblePerm[2]),
    ];
  });
  const [shifting, setShifting] = useState(false);

  useEffect(() => {
    const id = window.setInterval(() => {
      // Phase 1: slide every card +1 slot. The incoming card transitions
      // from -1 (off-screen left) to 0 (leftmost visible).
      setShifting(true);
      // Phase 2 (after the slide completes): pop the now-off-screen-right
      // card, push a fresh incoming card on the left, and reset positions.
      // React keeps the surviving DOM nodes by `id` so they don't jump.
      window.setTimeout(() => {
        setCards((prev) => {
          // Fresh card inherits the slap count of prev[2] — the card
          // that's about to drop off the right. This preserves the
          // {1,2,3} permutation invariant across visible slots.
          const fresh = nextFromPool(prev[2].slaps);
          return [fresh, prev[0], prev[1], prev[2]];
        });
        setShifting(false);
      }, SHIFT_MS);
    }, CYCLE_MS);
    return () => window.clearInterval(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div
      className="relative w-full"
      style={{ height: 540, overflow: "hidden" }}
    >
      {cards.map((c, i) => {
        // Idle: i=0 sits off-screen left (slot -1), i=1..3 occupy the
        // three visible slots 0..2. During the shift each card slides +1.
        const slot = shifting ? i : i - 1;
        return (
          <div
            key={c.id}
            className="absolute top-0"
            style={{
              // 3 cards + 2 gaps of 8px span the full width, so each
              // card+gap step is (100% + 8px) / 3.
              left: `calc(${slot} * (100% + 8px) / 3)`,
              width: "calc((100% - 16px) / 3)",
              transition: `left ${SHIFT_MS}ms cubic-bezier(0.22, 1, 0.36, 1)`,
            }}
          >
            <ModeCard mode={c.mode} slaps={c.slaps} />
          </div>
        );
      })}
    </div>
  );
}

function ModeCard({
  mode,
  slaps,
}: {
  mode: {
    slaps: number;
    name: string;
    tag: string;
    opens: string[];
    quits: string[];
    focus: string;
    color: string;
  };
  slaps: number;
}) {
  return (
    <div className="bg-[var(--paper)] border border-[var(--rule)] p-6 flex flex-col gap-5">
      <div className="flex items-start justify-between">
        <div>
          <div className="font-mono-tracked text-[10px] uppercase tracking-[0.3em] text-[var(--mute)] mb-1">
            {mode.tag}
          </div>
          <h3
            className="text-3xl font-serif text-[var(--ink)] leading-none"
            style={{ fontFamily: "var(--font-serif)" }}
          >
            {mode.name}
          </h3>
        </div>
        <SlapCountPip count={slaps} />
      </div>

      <div className="h-px bg-[var(--rule)]" />

      <div>
        <div className="font-mono-tracked text-[9px] uppercase tracking-[0.3em] text-[var(--accent)] mb-2">
          Opens
        </div>
        <ul className="space-y-1">
          {mode.opens.map((o) => (
            <li
              key={o}
              className="font-mono-tracked text-xs text-[var(--ink)]"
            >
              + {o}
            </li>
          ))}
        </ul>
      </div>
      <div>
        <div className="font-mono-tracked text-[9px] uppercase tracking-[0.3em] text-[var(--mute)] mb-2">
          Quits
        </div>
        <ul className="space-y-1">
          {mode.quits.map((q) => (
            <li
              key={q}
              className="font-mono-tracked text-xs text-[var(--ink)] line-through decoration-[var(--mute)]"
            >
              − {q}
            </li>
          ))}
        </ul>
      </div>
      <div className="mt-auto pt-2">
        <div className="font-mono-tracked text-[9px] uppercase tracking-[0.3em] text-[var(--mute)] mb-1">
          Focus
        </div>
        <div className="font-mono-tracked text-xs text-[var(--ink)]">
          ⌖ {mode.focus}
        </div>
      </div>
    </div>
  );
}

function SlapCountPip({ count }: { count: number }) {
  // Slap count drives color: 1 = accent red, 2 = sun yellow, 3 = hill green.
  // The pip is the only visual signal of "which slot is this" on each card,
  // so color is bound to count, not to the mode.
  const pipColor =
    count === 1
      ? "var(--accent)"
      : count === 2
        ? "var(--sun)"
        : "var(--hill)";
  return (
    <div className="flex flex-col items-center gap-1">
      <div className="flex gap-[3px]">
        {Array.from({ length: count }).map((_, i) => (
          <div
            key={i}
            className="w-2 h-2 pixelated"
            style={{ background: pipColor }}
          />
        ))}
        {Array.from({ length: 3 - count }).map((_, i) => (
          <div
            key={`e${i}`}
            className="w-2 h-2 pixelated border border-[var(--rule)]"
          />
        ))}
      </div>
      <div className="font-mono-tracked text-[9px] uppercase tracking-[0.25em] text-[var(--mute)]">
        {count} slap{count > 1 ? "s" : ""}
      </div>
    </div>
  );
}

// =============================================================================
// 03 — Also it does these things. 4-up feature grid.
// Centered alignment — break from the off-center modes section above.
// =============================================================================

function AlsoSection() {
  const features = [
    {
      icon: <IconMenubar />,
      title: "Menu bar only",
      body: "No dock icon. Lives quietly at the top of the screen.",
    },
    {
      icon: <IconSlider />,
      title: "Adjustable sensitivity",
      body: "From feather-tap to full open-hand commitment.",
    },
    {
      icon: <IconBolt />,
      title: "Launch at login",
      body: "Always listening. Wakes when you wake.",
    },
    {
      icon: <IconCounter />,
      title: "Slap counter",
      body: "Tracks your lifetime slaps. For science.",
    },
    {
      icon: <IconFlash />,
      title: "Instant feedback",
      body: "Menu-bar flash on first slap, before the action fires.",
    },
    {
      icon: <IconEdit />,
      title: "Mode editor",
      body: "Edit the defaults. Add apps, URLs, Focus modes.",
    },
    {
      icon: <IconCheck />,
      title: "Offline license",
      body: "Validated once. Cached locally. No daily phone-home.",
    },
    {
      icon: <IconTest />,
      title: "Test slap",
      body: "Fire any mode by button — no actual slap required.",
    },
  ];

  return (
    <section className="bg-[var(--cream-deeper)] py-24">
      <div className="max-w-6xl mx-auto px-8">
        <SectionLabel num="03" text="Also it does these things" align="center" />
        <h2
          className="text-4xl md:text-5xl font-serif text-[var(--ink)] text-center leading-[1.05] max-w-3xl mx-auto mb-14"
          style={{ fontFamily: "var(--font-serif)" }}
        >
          Small things that <em>add up</em>.
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-x-8 gap-y-10">
          {features.map((f) => (
            <div key={f.title} className="flex flex-col gap-3">
              <div className="w-10 h-10 bg-[var(--cream)] border border-[var(--rule)] flex items-center justify-center">
                {f.icon}
              </div>
              <h3 className="font-serif text-lg text-[var(--ink)] leading-tight">
                {f.title}
              </h3>
              <p className="font-mono-tracked text-xs text-[var(--mute)] leading-relaxed">
                {f.body}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

// =============================================================================
// 04 — Nerdy tech details. Right-aligned label, content in two columns.
// =============================================================================

function NerdySection() {
  const algos = [
    {
      name: "High-pass filter",
      body: "Strips out gravity so we only see actual impacts.",
    },
    {
      name: "STA/LTA ratio",
      body: "Compares short-term vs long-term acceleration averages across three timescales.",
    },
    {
      name: "CUSUM",
      body: "Detects sudden cumulative shifts the simple thresholds miss.",
    },
    {
      name: "Kurtosis",
      body: "Fourth statistical moment — finds the sharp spikes typing won't produce.",
    },
    {
      name: "Peak / MAD",
      body: "Median Absolute Deviation outlier detection. Tunable per-Mac.",
    },
  ];

  return (
    <section className="bg-[var(--cream)] py-24">
      <div className="max-w-6xl mx-auto px-8">
        <SectionLabel num="04" text="Nerdy tech details" align="right" />
        <div className="grid md:grid-cols-12 gap-10 items-start">
          <div className="md:col-span-5">
            <h2
              className="text-4xl md:text-5xl font-serif text-[var(--ink)] leading-[1.05] mb-6"
              style={{ fontFamily: "var(--font-serif)" }}
            >
              Wildly <em>overengineered</em> slap detection.
            </h2>
            <p className="font-mono-tracked text-xs text-[var(--mute)] leading-relaxed mb-6">
              Five concurrent signal-processing algorithms vote on whether
              you actually slapped your laptop. Democracy, but for physical
              abuse.
            </p>
            <div className="flex items-center gap-3">
              <PixelSensor />
              <div>
                <div className="font-mono-tracked text-[10px] uppercase tracking-[0.3em] text-[var(--mute)]">
                  Source
                </div>
                <div className="font-mono-tracked text-xs text-[var(--ink)]">
                  IOKit · AppleHIDMotion · ~100Hz
                </div>
              </div>
            </div>
          </div>
          <div className="md:col-span-7">
            <ol className="space-y-3">
              {algos.map((a, i) => (
                <li
                  key={a.name}
                  className="border-l-2 border-[var(--accent)] pl-4 py-1"
                >
                  <div className="flex items-baseline gap-3">
                    <span className="font-mono-tracked text-[10px] uppercase tracking-[0.3em] text-[var(--accent)]">
                      0{i + 1}
                    </span>
                    <span className="font-serif text-lg text-[var(--ink)]">
                      {a.name}
                    </span>
                  </div>
                  <p className="font-mono-tracked text-xs text-[var(--mute)] leading-relaxed mt-1">
                    {a.body}
                  </p>
                </li>
              ))}
            </ol>
            <div className="font-mono-tracked text-[10px] uppercase tracking-[0.3em] text-[var(--mute)] mt-6 text-center">
              ↓ when enough algorithms agree → action fires
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

// =============================================================================
// 05 — Architecture. Dark ASCII block, centered, mono.
// =============================================================================

// =============================================================================
// 07 — Price. Centered, big serif, big button.
// =============================================================================

function PriceSection() {
  // Two CTAs by design:
  //   1) Download DMG — free, no email gate. Paywall fires in-app after the
  //      first real slap. This is the primary path for most people.
  //   2) Buy License — for impulse buyers who want to pay before downloading.
  //      Hits /api/checkout, redirects to Stripe. Success page hands back the key.
  const [buying, setBuying] = useState(false);

  async function onBuy() {
    if (buying) return;
    setBuying(true);
    try {
      const res = await fetch("/api/checkout", { method: "POST" });
      const data: { url?: string; error?: string } = await res.json();
      if (data.url) {
        window.location.href = data.url;
      } else {
        setBuying(false);
        alert("Couldn't start checkout. Please try again or email support@slapshift.app.");
      }
    } catch {
      setBuying(false);
      alert("Network error starting checkout. Please try again.");
    }
  }

  return (
    <section className="bg-[var(--cream-deeper)] py-28">
      <div className="max-w-3xl mx-auto px-8 text-center">
        <SectionLabel num="07" text="Pricing" align="center" />
        <div className="flex items-baseline justify-center gap-3 mb-4">
          <span
            className="text-7xl md:text-8xl font-serif text-[var(--ink)] leading-none"
            style={{ fontFamily: "var(--font-serif)" }}
          >
            $9.99
          </span>
          <span className="font-mono-tracked text-xs uppercase tracking-[0.3em] text-[var(--mute)]">
            one-time
          </span>
        </div>
        <p
          className="text-2xl md:text-3xl font-serif text-[var(--ink)] leading-tight mb-8"
          style={{ fontFamily: "var(--font-serif)" }}
        >
          Less than a sad desk lunch.
          <br />
          <em>Try free</em> — pay when you're hooked.
        </p>
        <p className="font-mono-tracked text-xs text-[var(--mute)] mb-10 max-w-md mx-auto leading-relaxed">
          Requires an Apple Silicon MacBook (M1 or newer) and a willingness
          to hit expensive things. All sales final, no refunds.
        </p>
        <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
          <a
            href="/downloads/SlapShift-0.1.0.dmg"
            className="group inline-flex items-center gap-3 bg-[var(--ink)] text-[var(--cream)] px-8 py-4 font-mono-tracked text-xs uppercase tracking-[0.25em] hover:bg-[var(--accent)] transition-colors"
          >
            <DownloadIcon />
            <span>Download for macOS</span>
          </a>
          <button
            type="button"
            onClick={onBuy}
            disabled={buying}
            className="inline-flex items-center gap-3 border border-[var(--ink)] text-[var(--ink)] px-8 py-4 font-mono-tracked text-xs uppercase tracking-[0.25em] hover:bg-[var(--ink)] hover:text-[var(--cream)] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {buying ? "Opening Stripe…" : "Buy license — $9.99"}
          </button>
        </div>
        <div className="font-mono-tracked text-[10px] uppercase tracking-[0.3em] text-[var(--mute)] mt-4">
          v0.1.0 · 4.2 MB · Apple Silicon · Updated May 2026
        </div>
      </div>
    </section>
  );
}

// =============================================================================
// 08 — FAQ. Right-aligned label. Accordion list.
// =============================================================================

function FaqSection() {
  const faqs = [
    {
      q: "Is this an actual product or a bit?",
      a: "Both, honestly. The slap is the joke. The thing it does — collapsing your morning app-opening routine into one motion — is the real product. The toy is just the wrapper.",
    },
    {
      q: "What if I just close the lid hard? Does it fire?",
      a: "Nope. The detector is tuned to the signature of an open-palm hit on the deck, not the rotational shock of a lid slam. Slamming, dropping, sneezing on it — all ignored.",
    },
    {
      q: "I'm on an Intel MacBook. Am I locked out?",
      a: "Unfortunately yes. The accelerometer trick only works on Apple Silicon. M1 or newer required — there's no Intel path forward.",
    },
    {
      q: "Am I stuck with the default modes?",
      a: "The three defaults — Coding, Apply, Wind Down — are fully editable. Add apps, swap URLs, change the Focus mode, rename them. You're not locked into the presets.",
    },
    {
      q: "Be honest — am I going to crack my screen?",
      a: "Open-palm tap, not karate chop. If you'd be comfortable high-fiving the deck, you're in the safe zone. Don't get creative.",
    },
    {
      q: "How bad is this for my battery?",
      a: "Barely measurable. The motion sensor pulls roughly the same power as a backlight tick. Under 1% extra drain over a full workday.",
    },
    {
      q: "I work in an open office. People will stare.",
      a: "They will. Either you become the slap guy, or you reroute the gesture to a quieter trigger (we're working on a tap variant). For now, lean into it.",
    },
    {
      q: "Where's the Windows version?",
      a: "There isn't one. Windows laptops don't expose motion data the same way Apple Silicon does. Even if they did, the gesture lives and dies with macOS taste.",
    },
  ];

  return (
    <section className="bg-[var(--cream)] py-24">
      <div className="max-w-4xl mx-auto px-8">
        <SectionLabel num="08" text="Frequently asked" align="center" />
        <h2
          className="text-4xl md:text-5xl font-serif text-[var(--ink)] text-center leading-[1.05] mb-12"
          style={{ fontFamily: "var(--font-serif)" }}
        >
          You probably wanted to <em>ask</em>.
        </h2>
        <div className="border-t border-[var(--rule)]">
          {faqs.map((f) => (
            <FaqItem key={f.q} q={f.q} a={f.a} />
          ))}
        </div>
      </div>
    </section>
  );
}

function FaqItem({ q, a }: { q: string; a: string }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="border-b border-[var(--rule)]">
      <button
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-center justify-between text-left py-5 group"
      >
        <span className="font-serif text-lg md:text-xl text-[var(--ink)] leading-tight pr-6">
          {q}
        </span>
        <span
          className="font-mono-tracked text-lg text-[var(--accent)] transition-transform"
          style={{ transform: open ? "rotate(45deg)" : "rotate(0deg)" }}
        >
          +
        </span>
      </button>
      {open && (
        <p className="font-mono-tracked text-sm text-[var(--mute)] leading-relaxed pb-6 max-w-3xl">
          {a}
        </p>
      )}
    </div>
  );
}

// =============================================================================
// Footer.
// =============================================================================

// =============================================================================
// Skyline footer. Pixel-art city + setting sun, static. Only clouds drift.
// Palette matches the café hero so the two scenes feel like one world.
// =============================================================================

function Footer() {
  // Layout math:
  //   FOOTER_H = SKY_H (cream space for clouds + credit) + SKYLINE_H (city).
  //   The credit stack lives entirely in SKY_H, so it can never overlap
  //   the buildings — its bottom edge is bounded by SKY_H.
  const SKYLINE_H = 640; // up from 440 — +200 as requested
  const SKY_H = 320;     // headroom for "Made by / Matthew Park / Creator"
  const FOOTER_H = SKY_H + SKYLINE_H;

  return (
    <footer className="relative w-full overflow-hidden bg-[var(--cream)]">
      <div className="relative w-full" style={{ height: FOOTER_H }}>
        {/* Drifting clouds — only animated element in the footer. Confined
            to SKY_H so they never drift over the buildings. */}
        <PixelCloud top={50}  duration={140} delay={0}    scale={1.1} />
        <PixelCloud top={140} duration={180} delay={-55}  scale={1.5} />
        <PixelCloud top={230} duration={155} delay={-30}  scale={1.0} />
        <PixelCloud top={90}  duration={210} delay={-130} scale={1.25} />

        {/* Stacked credit: Made by / Matthew Park / Creator.
            Vertically centered inside the sky band so it can't overlap
            the skyline regardless of viewport width. */}
        <div
          className="absolute inset-x-0 z-10 flex justify-center"
          style={{ top: 110 }}
        >
          <a
            href="https://matthewnpark.com"
            target="_blank"
            rel="noopener noreferrer"
            className="group flex flex-col items-center text-center text-[var(--ink)] hover:text-[var(--accent)] transition-colors"
          >
            <span className="font-mono-tracked text-sm md:text-base uppercase tracking-[0.35em]">
              Made by
            </span>
            <span
              className="font-serif italic text-6xl md:text-[5rem] leading-[1.05] mt-3"
              style={{ fontFamily: "var(--font-serif)" }}
            >
              Matthew Park
            </span>
            <span className="font-mono-tracked text-sm md:text-base uppercase tracking-[0.35em] mt-3">
              Creator
            </span>
          </a>
        </div>

        {/* Pixel skyline — full-bleed, anchored to bottom. Buildings stretch
            horizontally to cover the entire width. Sun is rendered as a
            separate non-stretched layer so it stays circular. */}
        <div
          className="absolute bottom-0 left-0 right-0 z-0"
          style={{ height: SKYLINE_H }}
        >
          <PixelSkyline />
        </div>
      </div>
    </footer>
  );
}

function PixelCloud({
  top,
  duration,
  delay,
  scale = 1,
}: {
  top: number;
  duration: number;
  delay: number;
  scale?: number;
}) {
  return (
    <div
      className="absolute"
      style={{
        top,
        left: 0,
        animation: `walk-ltr ${duration}s linear infinite`,
        animationDelay: `${delay}s`,
        transform: `scale(${scale})`,
        transformOrigin: "left center",
        pointerEvents: "none",
      }}
    >
      <svg width={140} height={50} viewBox="0 0 70 25" className="pixelated">
        <rect x={10} y={8} width={50} height={10} fill="var(--cloud)" />
        <rect x={6} y={10} width={4} height={6} fill="var(--cloud)" />
        <rect x={60} y={10} width={4} height={6} fill="var(--cloud)" />
        <rect x={16} y={4} width={12} height={4} fill="var(--cloud)" />
        <rect x={34} y={2} width={16} height={6} fill="var(--cloud)" />
        <rect x={50} y={6} width={8} height={2} fill="var(--cloud)" />
        <rect x={22} y={18} width={26} height={2} fill="var(--cloud)" />
      </svg>
    </div>
  );
}

function PixelSkyline() {
  // viewBox 1600x440 — wider so the natural aspect ratio is closer to a
  // browser-width footer, which means the slice crop is gentle. Buildings
  // span the FULL width edge-to-edge. Sun is split out to its own layer
  // (rendered absolutely) so it stays circular under any scaling.
  //
  // Buildings: [x, y, width, height, deep?]
  const buildings: [number, number, number, number, boolean][] = [
    [0,    240, 50, 160, false],
    [46,   180, 60, 220, true],
    [102,  260, 44, 140, false],
    [142,  120, 64, 280, true],
    [202,  200, 56, 200, false],
    [254,  150, 60, 250, true],
    [310,  220, 52, 180, false],
    [358,  170, 68, 230, true],
    [422,  110, 50, 290, false],
    [468,  200, 60, 200, true],
    [524,  150, 56, 250, false],
    [576,  220, 64, 180, true],
    [636,  170, 56, 230, false],
    [688,  130, 60, 270, true],
    [744,  210, 54, 190, false],
    [794,  160, 60, 240, false],
    [850,  230, 50, 170, true],
    [896,  180, 58, 220, false],
    [950,  130, 54, 270, true],
    [1000, 210, 56, 190, false],
    [1052, 160, 62, 240, true],
    [1110, 220, 50, 180, false],
    [1156, 140, 60, 260, true],
    [1212, 200, 54, 200, false],
    [1262, 170, 60, 230, true],
    [1318, 230, 48, 170, false],
    [1362, 150, 58, 250, true],
    [1416, 200, 56, 200, false],
    [1468, 130, 64, 270, true],
    [1528, 180, 50, 220, false],
    [1574, 210, 26, 190, true],
  ];

  // Deterministic window grid per building so windows hug walls instead of
  // floating in the sky. Window cells are 4x4, separated by 4px gutters.
  const windows: { x: number; y: number }[] = [];
  buildings.forEach(([bx, by, bw, bh], bi) => {
    const cols = Math.max(2, Math.floor(bw / 10));
    const rows = Math.max(3, Math.floor(bh / 14));
    const padX = (bw - cols * 4 - (cols - 1) * 4) / 2;
    for (let c = 0; c < cols; c++) {
      for (let r = 0; r < rows; r++) {
        if (((bi * 31 + c * 7 + r * 13) % 11) < 3) continue;
        windows.push({
          x: bx + padX + c * 8,
          y: by + 10 + r * 10,
        });
      }
    }
  });

  return (
    <div className="relative w-full h-full">
      {/* Buildings layer — stretched edge-to-edge with preserveAspectRatio
          "none". All shapes are rectangles, so non-uniform stretch is
          invisible. */}
      <svg
        width="100%"
        height="100%"
        viewBox="0 0 1600 400"
        preserveAspectRatio="none"
        className="pixelated block absolute inset-0"
      >
        {buildings.map(([x, y, w, h, deep], i) => (
          <rect
            key={`b-${i}`}
            x={x}
            y={y}
            width={w}
            height={h}
            fill={deep ? "var(--building-rose-deep)" : "var(--building-rose)"}
          />
        ))}
        {windows.map((w, i) => (
          <rect key={`w-${i}`} x={w.x} y={w.y} width={4} height={4} fill="var(--window)" />
        ))}
      </svg>

      {/* Sun layer — separate absolutely-positioned SVG so the circle stays
          circular regardless of horizontal stretch. Raised 30px and nudged
          right relative to the previous position. */}
      <div
        className="absolute pointer-events-none"
        style={{ right: "calc(4% + 10px)", top: 60, width: 96, height: 96 }}
      >
        <svg width={96} height={96} viewBox="0 0 96 96" className="pixelated block">
          <circle cx={48} cy={48} r={44} fill="var(--accent)" opacity={0.16} />
          <circle cx={48} cy={48} r={34} fill="var(--accent)" opacity={0.30} />
          <rect x={32} y={32} width={32} height={32} fill="var(--accent)" />
          <rect x={26} y={38} width={6}  height={20} fill="var(--accent)" />
          <rect x={64} y={38} width={6}  height={20} fill="var(--accent)" />
          <rect x={38} y={26} width={20} height={6}  fill="var(--accent)" />
          <rect x={38} y={64} width={20} height={6}  fill="var(--accent)" />
        </svg>
      </div>
    </div>
  );
}

// =============================================================================
// Tiny pixel icons — match the hero's pixel-art language.
// 16x16 viewBox, square cells.
// =============================================================================

const ICO = "var(--ink)";
const ACC = "var(--accent)";

function IconMenubar() {
  return (
    <svg width="20" height="20" viewBox="0 0 16 16" className="pixelated">
      <rect x={1} y={3} width={14} height={3} fill={ICO} />
      <rect x={3} y={4} width={1} height={1} fill={ACC} />
      <rect x={5} y={4} width={1} height={1} fill={ACC} />
      <rect x={1} y={8} width={14} height={5} fill="none" stroke={ICO} strokeWidth={1} />
    </svg>
  );
}
function IconSlider() {
  return (
    <svg width="20" height="20" viewBox="0 0 16 16" className="pixelated">
      <rect x={1} y={4} width={14} height={1} fill={ICO} />
      <rect x={5} y={2} width={2} height={5} fill={ACC} />
      <rect x={1} y={10} width={14} height={1} fill={ICO} />
      <rect x={10} y={8} width={2} height={5} fill={ACC} />
    </svg>
  );
}
function IconBolt() {
  return (
    <svg width="20" height="20" viewBox="0 0 16 16" className="pixelated">
      <rect x={8} y={1} width={3} height={2} fill={ACC} />
      <rect x={6} y={3} width={3} height={2} fill={ACC} />
      <rect x={4} y={5} width={5} height={2} fill={ACC} />
      <rect x={7} y={7} width={3} height={2} fill={ACC} />
      <rect x={5} y={9} width={3} height={2} fill={ACC} />
      <rect x={3} y={11} width={3} height={2} fill={ACC} />
    </svg>
  );
}
function IconCounter() {
  return (
    <svg width="20" height="20" viewBox="0 0 16 16" className="pixelated">
      <rect x={2} y={10} width={2} height={4} fill={ICO} />
      <rect x={5} y={7} width={2} height={7} fill={ICO} />
      <rect x={8} y={4} width={2} height={10} fill={ACC} />
      <rect x={11} y={2} width={2} height={12} fill={ICO} />
    </svg>
  );
}
function IconFlash() {
  return (
    <svg width="20" height="20" viewBox="0 0 16 16" className="pixelated">
      <rect x={7} y={7} width={2} height={2} fill={ACC} />
      <rect x={7} y={1} width={2} height={2} fill={ICO} />
      <rect x={7} y={13} width={2} height={2} fill={ICO} />
      <rect x={1} y={7} width={2} height={2} fill={ICO} />
      <rect x={13} y={7} width={2} height={2} fill={ICO} />
      <rect x={3} y={3} width={2} height={2} fill={ICO} />
      <rect x={11} y={3} width={2} height={2} fill={ICO} />
      <rect x={3} y={11} width={2} height={2} fill={ICO} />
      <rect x={11} y={11} width={2} height={2} fill={ICO} />
    </svg>
  );
}
function IconEdit() {
  return (
    <svg width="20" height="20" viewBox="0 0 16 16" className="pixelated">
      <rect x={2} y={11} width={3} height={3} fill={ACC} />
      <rect x={5} y={8} width={3} height={3} fill={ICO} />
      <rect x={8} y={5} width={3} height={3} fill={ICO} />
      <rect x={11} y={2} width={3} height={3} fill={ICO} />
    </svg>
  );
}
function IconCheck() {
  return (
    <svg width="20" height="20" viewBox="0 0 16 16" className="pixelated">
      <rect x={2} y={8} width={2} height={2} fill={ICO} />
      <rect x={4} y={10} width={2} height={2} fill={ICO} />
      <rect x={6} y={8} width={2} height={2} fill={ACC} />
      <rect x={8} y={6} width={2} height={2} fill={ACC} />
      <rect x={10} y={4} width={2} height={2} fill={ACC} />
      <rect x={12} y={2} width={2} height={2} fill={ACC} />
    </svg>
  );
}
function IconTest() {
  return (
    <svg width="20" height="20" viewBox="0 0 16 16" className="pixelated">
      <rect x={3} y={2} width={10} height={2} fill={ICO} />
      <rect x={5} y={4} width={6} height={2} fill={ICO} />
      <rect x={6} y={6} width={4} height={6} fill={ACC} />
      <rect x={4} y={12} width={8} height={2} fill={ICO} />
    </svg>
  );
}
function PixelSensor() {
  return (
    <svg width="40" height="40" viewBox="0 0 20 20" className="pixelated">
      <rect x={9} y={9} width={2} height={2} fill={ACC} />
      <rect x={7} y={7} width={6} height={1} fill={ICO} />
      <rect x={7} y={12} width={6} height={1} fill={ICO} />
      <rect x={7} y={7} width={1} height={6} fill={ICO} />
      <rect x={12} y={7} width={1} height={6} fill={ICO} />
      <rect x={4} y={4} width={12} height={1} fill={ICO} opacity={0.4} />
      <rect x={4} y={15} width={12} height={1} fill={ICO} opacity={0.4} />
      <rect x={4} y={4} width={1} height={12} fill={ICO} opacity={0.4} />
      <rect x={15} y={4} width={1} height={12} fill={ICO} opacity={0.4} />
    </svg>
  );
}

// =============================================================================
// Café background — wall, floor, pendant lights, counter w/ barista, customers,
// plants, side table with steam.
// =============================================================================

function CafeBackground() {
  return (
    <>
      {/* Warm wall */}
      <div className="absolute inset-0 bg-[#e6dcc1]" />
      {/* Wood floor band */}
      <div className="absolute bottom-0 left-0 right-0 h-[14%] bg-[#7a5a3a]" />
      <div
        className="absolute left-0 right-0 h-[2px] bg-[#5a3f25]"
        style={{ bottom: "14%" }}
      />

      {/* Pendant lights */}
      <PendantLight x="18%" />
      <PendantLight x="50%" />
      <PendantLight x="82%" />

      {/* Barista — rendered BEFORE counter so the counter masks her lower body.
          Head/shoulders poke above the counter top. Paces left↔right. */}
      <div
        className="absolute"
        style={{
          left: "0%",
          bottom: "20%",
          width: "30%",
          pointerEvents: "none",
        }}
      >
        <div
          style={{
            animation: "barista-pace 5.2s ease-in-out infinite",
            transformOrigin: "center bottom",
            width: 44,
          }}
        >
          <BackgroundPerson shirt="#3a3a3a" hair="#2a1d16" apron />
        </div>
      </div>

      {/* Counter on far left — masks barista's lower body */}
      <CafeCounter x="-2%" />

      {/* Tables — aligned in a single line along the floor (like the cacti
          stand on the same baseline). 1 on the LEFT past the counter, 2 on
          the RIGHT past the bench/character. Each table has chairs built in
          so seated NPCs read as actually sitting. */}
      <div
        className="absolute"
        style={{ left: "25vw", bottom: "12%", zIndex: 10 }}
      >
        <TableUnit />
        <SteamPuff x={40} delay={-0.4} />
      </div>
      <div
        className="absolute"
        style={{ left: "65vw", bottom: "12%", zIndex: 10 }}
      >
        <TableUnit />
        <SteamPuff x={40} delay={0} />
      </div>
      <div
        className="absolute"
        style={{ left: "80vw", bottom: "12%", zIndex: 10 }}
      >
        <TableUnit />
        <SteamPuff x={44} delay={-1.2} />
      </div>

      {/* Plant on the far right wall. */}
      <div className="absolute" style={{ right: "2%", bottom: "14%" }}>
        <PixelPlant />
      </div>

      {/* NPC SIMULATION — up to 15 people. They enter from the right with
          stepping legs, queue at the counter, get a randomized drink, walk
          to a free seat at one of the three tables, sit for a randomized
          duration, then either leave or stay to talk with whoever else
          happens to be at their table. Fully stateful so spawn intervals,
          drink wait time, sit duration, and interaction outcomes are all
          randomized per NPC — not synchronized loops. */}
      <CafeSimulation />
    </>
  );
}

// =============================================================================
// Café simulation — stateful NPC sim. Replaces the old CSS-keyframe walking
// loops. Each NPC is a finite state machine ticked at TICK_MS:
//
//   entering ──► queueing ──► to_table ──► sitting ──┬─► talking ──► leaving
//                    │                               │              ▲
//                    └───► leaving (no free seat)    └──────────────┘
//
// Spawn cadence, drink wait, sit duration, talk decision, walk speed, and
// appearance are all randomized per NPC. Seats are tracked so two people
// never claim the same chair. Max population is capped at MAX_PEOPLE.
// =============================================================================

type PersonState =
  | "entering"
  | "queueing"
  | "to_table"
  | "sitting"
  | "talking"
  | "leaving";

type Facing = "front" | "back" | "left" | "right";

type Person = {
  id: number;
  state: PersonState;
  x: number; // current x position in vw
  targetX: number; // destination for movement states
  shirt: string;
  hair: string;
  pants: string;
  drink: string;
  hasDrink: boolean;
  tableIdx: number | null;
  seatIdx: 0 | 1 | null;
  timer: number; // ms left in current state
  speed: number; // vw / second
  // Sitting expression — pseudo-3D head turn via pixel-art eye shift.
  // Cycles every few seconds while seated; biases toward neighbor when
  // talking so the two NPCs visibly look at each other.
  facing: Facing;
  poseTimer: number;
  // Sip animation — drink rises to face for a short window, repeats.
  sipping: boolean;
  sipTimer: number;
  // Per-NPC queue position — spread along the counter so arrivals
  // don't all pile up on the same pixel.
  queueX: number;
};

const SHIRT_COLORS = [
  "#5a7a4a",
  "#d4a44a",
  "#6a4a7a",
  "#3a5a8a",
  "#c83a26",
  "#3a7a6a",
  "#a55a3a",
  "#7a5a8a",
  "#4a6a8a",
];
const HAIR_COLORS = [
  "#7a5a3a",
  "#2a1d16",
  "#3a2a1a",
  "#c8a05a",
  "#4a2a1a",
  "#6a3a1a",
  "#1a1a1a",
];
const PANTS_COLORS = ["#34425a", "#3a3a3a", "#5a3a2a", "#2a3a4a", "#3a4a3a"];
const DRINK_COLORS = [
  "#2a1a10", // espresso
  "#c8a07a", // latte
  "#7a9a4a", // matcha
  "#d47a8a", // strawberry
  "#e8d4a0", // chai
  "#5a3a2a", // mocha
  "#a55a3a", // caramel
];

// Each table is anchored by its left edge in vw. Two seat-slots per table —
// left chair and right chair. Seat positions are absolute vw so SimPerson can
// just write `left: ${x}vw` without knowing about the table layout.
const SIM_TABLES = [
  { leftVw: 25, seats: [25.5, 30.4] as [number, number] },
  { leftVw: 65, seats: [65.5, 70.4] as [number, number] },
  { leftVw: 80, seats: [80.5, 85.4] as [number, number] },
];

const COUNTER_X = 22; // vw — front of counter where NPCs queue
const SPAWN_X = 115; // vw — off-screen right
const MAX_PEOPLE = 15;
const TICK_MS = 80;

const rand = (min: number, max: number) =>
  Math.random() * (max - min) + min;
const pick = <T,>(arr: readonly T[]): T =>
  arr[Math.floor(Math.random() * arr.length)];

function CafeSimulation() {
  const [people, setPeople] = useState<Person[]>([]);
  const nextIdRef = useRef(0);
  const nextSpawnRef = useRef(800); // first spawn ~800ms in

  useEffect(() => {
    const interval = window.setInterval(() => {
      setPeople((prev) => {
        // Build occupancy snapshot up front so claims stay consistent
        // across this tick's transitions.
        const seatTaken = new Set<string>();
        for (const p of prev) {
          if (
            (p.state === "to_table" ||
              p.state === "sitting" ||
              p.state === "talking") &&
            p.tableIdx !== null &&
            p.seatIdx !== null
          ) {
            seatTaken.add(`${p.tableIdx}-${p.seatIdx}`);
          }
        }

        const dt = TICK_MS / 1000; // seconds per tick
        const next: Person[] = [];

        for (const p of prev) {
          const np: Person = { ...p, timer: p.timer - TICK_MS };

          if (np.state === "entering") {
            np.x -= np.speed * dt;
            if (np.x <= np.queueX) {
              np.x = np.queueX;
              np.state = "queueing";
              np.timer = rand(2500, 5500);
            }
          } else if (np.state === "queueing") {
            if (np.timer <= 0) {
              np.hasDrink = true;
              // Try to claim a free seat. Shuffle table order so NPCs
              // don't all pile into table 0.
              const tableOrder = [0, 1, 2].sort(() => Math.random() - 0.5);
              let claimed: { tableIdx: number; seatIdx: 0 | 1 } | null = null;
              for (const ti of tableOrder) {
                for (const si of [0, 1] as const) {
                  if (!seatTaken.has(`${ti}-${si}`)) {
                    claimed = { tableIdx: ti, seatIdx: si };
                    seatTaken.add(`${ti}-${si}`);
                    break;
                  }
                }
                if (claimed) break;
              }
              if (claimed) {
                np.tableIdx = claimed.tableIdx;
                np.seatIdx = claimed.seatIdx;
                np.targetX = SIM_TABLES[claimed.tableIdx].seats[claimed.seatIdx];
                np.state = "to_table";
              } else {
                // café is full — drink and dash
                np.state = "leaving";
                np.targetX = SPAWN_X;
              }
            }
          } else if (np.state === "to_table") {
            const dir = np.targetX > np.x ? 1 : -1;
            np.x += dir * np.speed * dt;
            if (Math.abs(np.x - np.targetX) < 0.4) {
              np.x = np.targetX;
              np.state = "sitting";
              np.timer = rand(9000, 22000);
              // Initial seated pose — face toward the center of the table
              // (seat 0 is left chair → look right; seat 1 is right chair
              // → look left). This makes pairs read as facing each other
              // by default; the cycle below shuffles it from there.
              np.facing = np.seatIdx === 0 ? "right" : "left";
              np.poseTimer = rand(2200, 4500);
            }
          } else if (np.state === "sitting") {
            if (np.timer <= 0) {
              // Maybe stay to chat if there's someone else at this table.
              const neighbor = prev.find(
                (o) =>
                  o.id !== np.id &&
                  o.tableIdx === np.tableIdx &&
                  (o.state === "sitting" || o.state === "talking"),
              );
              if (neighbor && Math.random() < 0.5) {
                np.state = "talking";
                np.timer = rand(5000, 12000);
              } else {
                np.state = "leaving";
                np.targetX = SPAWN_X;
                np.tableIdx = null;
                np.seatIdx = null;
              }
            }
          } else if (np.state === "talking") {
            if (np.timer <= 0) {
              np.state = "leaving";
              np.targetX = SPAWN_X;
              np.tableIdx = null;
              np.seatIdx = null;
            }
          } else if (np.state === "leaving") {
            np.x += np.speed * dt;
            if (np.x > SPAWN_X + 5) {
              continue; // despawn off-screen
            }
          }

          // Seated pose cycle — head turns. When there's another person
          // at the same table, lock heavily toward them so pairs visibly
          // make eye contact. Solo sitters drift through random poses.
          if (np.state === "sitting" || np.state === "talking") {
            np.poseTimer -= TICK_MS;
            if (np.poseTimer <= 0) {
              const neighbor = prev.find(
                (o) =>
                  o.id !== np.id &&
                  o.tableIdx === np.tableIdx &&
                  (o.state === "sitting" || o.state === "talking"),
              );
              const towardNeighbor: Facing =
                np.seatIdx === 0 ? "right" : "left";
              if (np.state === "talking") {
                // Mid-conversation: hold the gaze longer between cycles
                // and glance away only rarely.
                np.poseTimer = rand(3500, 6500);
                np.facing =
                  Math.random() < 0.94
                    ? towardNeighbor
                    : pick(["front", "back", "left", "right"] as const);
              } else if (neighbor) {
                // Sitting with someone but not actively in talking state
                // — still look at them most of the time.
                np.poseTimer = rand(2800, 5200);
                np.facing =
                  Math.random() < 0.85
                    ? towardNeighbor
                    : pick(["front", "back", "left", "right"] as const);
              } else {
                // Alone at the table — random idle glances.
                np.poseTimer = rand(2200, 4500);
                np.facing = pick(["front", "back", "left", "right"] as const);
              }
            }
            // Sip cycle — drink rises to face for ~0.8s every few seconds.
            if (np.hasDrink) {
              np.sipTimer -= TICK_MS;
              if (np.sipTimer <= 0) {
                if (np.sipping) {
                  np.sipping = false;
                  np.sipTimer = rand(3500, 7500);
                } else {
                  np.sipping = true;
                  np.sipTimer = rand(650, 1100);
                }
              }
            }
          } else {
            // Not seated — keep the sip flag off so leaving NPCs don't
            // carry a raised drink off-screen.
            np.sipping = false;
          }

          next.push(np);
        }

        // Spawn new NPCs at randomized intervals, respecting the cap.
        nextSpawnRef.current -= TICK_MS;
        if (nextSpawnRef.current <= 0 && next.length < MAX_PEOPLE) {
          nextSpawnRef.current = rand(1800, 4800);
          // Pick a queue position that doesn't crowd anyone already in
          // line. Spread across [QUEUE_X_MIN, QUEUE_X_MAX]; if a candidate
          // is within MIN_QUEUE_GAP of an existing waiter, try again.
          const inQueue = next
            .filter(
              (o) => o.state === "entering" || o.state === "queueing",
            )
            .map((o) => o.queueX);
          let queueX = COUNTER_X + rand(0, 10);
          for (let attempt = 0; attempt < 6; attempt++) {
            const candidate = COUNTER_X + rand(-4, 11);
            const tooClose = inQueue.some(
              (qx) => Math.abs(qx - candidate) < 3.2,
            );
            if (!tooClose) {
              queueX = candidate;
              break;
            }
          }
          next.push({
            id: nextIdRef.current++,
            state: "entering",
            x: SPAWN_X,
            targetX: queueX,
            shirt: pick(SHIRT_COLORS),
            hair: pick(HAIR_COLORS),
            pants: pick(PANTS_COLORS),
            drink: pick(DRINK_COLORS),
            hasDrink: false,
            tableIdx: null,
            seatIdx: null,
            timer: 0,
            speed: rand(6.5, 10),
            facing: "front",
            poseTimer: 0,
            sipping: false,
            sipTimer: rand(2500, 5000),
            queueX,
          });
        }

        return next;
      });
    }, TICK_MS);
    return () => window.clearInterval(interval);
  }, []);

  return (
    <>
      {people.map((p) => (
        <SimPerson key={p.id} p={p} />
      ))}
    </>
  );
}

function SimPerson({ p }: { p: Person }) {
  const walking =
    p.state === "entering" || p.state === "to_table" || p.state === "leaving";
  // Face right when leaving (walking off-screen right). For to_table the
  // direction depends on whether the seat is left/right of current x.
  let facingRight = false;
  if (p.state === "leaving") facingRight = true;
  else if (p.state === "to_table" && p.targetX > p.x) facingRight = true;

  const seated = p.state === "sitting" || p.state === "talking";
  // Seated people sit BEHIND the table so the tabletop edge crops their
  // lower body. Walkers walk in FRONT of tables.
  const z = seated ? 5 : 15;

  return (
    <div
      className="absolute pointer-events-none"
      style={{
        left: `${p.x}vw`,
        bottom: "13%",
        transform: `translateX(-50%)${facingRight ? " scaleX(-1)" : ""}`,
        zIndex: z,
        // Smooth out the FSM's discrete tick updates. The walking state
        // bumps x once per TICK_MS; without a CSS transition the motion
        // reads as choppy at this tick rate, so let the browser
        // interpolate between samples. transform is intentionally NOT
        // animated so the scaleX facing flip is instantaneous (no fold).
        transition: `left ${TICK_MS}ms linear`,
      }}
    >
      <div className="relative">
        <BackgroundPerson
          shirt={p.shirt}
          hair={p.hair}
          pants={p.pants}
          walking={walking}
          facing={seated ? p.facing : "front"}
          sipping={seated && p.sipping}
        />
        {p.hasDrink && (
          <div
            className="absolute"
            style={{
              // Resting: drink at chest level. Sipping: lift to mouth.
              left: p.sipping ? 24 : 30,
              top: p.sipping ? 12 : 30,
              transition: "top 280ms cubic-bezier(0.22, 1, 0.36, 1), left 280ms cubic-bezier(0.22, 1, 0.36, 1)",
            }}
          >
            <PixelDrink color={p.drink} />
          </div>
        )}
        {p.state === "talking" && (
          <div
            className="absolute font-mono-tracked"
            style={{
              left: 38,
              top: -4,
              fontSize: 10,
              color: "var(--mute)",
              letterSpacing: "0.2em",
              transform: facingRight ? "scaleX(-1)" : undefined,
            }}
          >
            · · ·
          </div>
        )}
      </div>
    </div>
  );
}

function PixelDrink({ color }: { color: string }) {
  return (
    <svg width="14" height="18" viewBox="0 0 14 18" className="pixelated">
      {/* Lid */}
      <rect x={1} y={0} width={12} height={3} fill="#4a2e1c" />
      <rect x={5} y={1} width={4} height={2} fill="#2a1a10" />
      {/* Cup body */}
      <rect x={2} y={3} width={10} height={13} fill={color} />
      <rect x={2} y={3} width={2} height={13} fill="#000" opacity={0.18} />
      <rect x={10} y={3} width={2} height={13} fill="#fff" opacity={0.12} />
      {/* Sleeve */}
      <rect x={2} y={8} width={10} height={3} fill="#8a6a44" />
      <rect x={2} y={8} width={10} height={1} fill="#5a3f25" />
      {/* Base */}
      <rect x={3} y={16} width={8} height={2} fill="#2a1a10" />
    </svg>
  );
}

// =============================================================================
// Café props
// =============================================================================

function CafeCounter({ x }: { x: string }) {
  return (
    <div className="absolute" style={{ left: x, bottom: "14%", width: 360 }}>
      <svg width="360" height="180" viewBox="0 0 360 180" className="pixelated">
        <rect x={0} y={80} width={360} height={100} fill="#7a5a3a" />
        <rect x={0} y={80} width={360} height={6} fill="#5a3f25" />
        <rect x={40} y={100} width={4} height={70} fill="#5a3f25" />
        <rect x={120} y={100} width={4} height={70} fill="#5a3f25" />
        <rect x={200} y={100} width={4} height={70} fill="#5a3f25" />
        <rect x={280} y={100} width={4} height={70} fill="#5a3f25" />
        {/* Espresso machine */}
        <rect x={20} y={48} width={80} height={32} fill="#3a3a3a" />
        <rect x={30} y={56} width={20} height={12} fill="#c83a26" />
        <rect x={60} y={56} width={20} height={12} fill="#c83a26" />
        <rect x={36} y={68} width={8} height={6} fill="#5a5a5a" />
        <rect x={66} y={68} width={8} height={6} fill="#5a5a5a" />
        {/* Pastry case */}
        <rect x={130} y={56} width={100} height={24} fill="#d9d4be" opacity={0.85} />
        <rect x={130} y={54} width={100} height={4} fill="#5a3f25" />
        <rect x={140} y={62} width={14} height={14} fill="#c8907e" />
        <rect x={160} y={62} width={14} height={14} fill="#d4a44a" />
        <rect x={180} y={62} width={14} height={14} fill="#a55a3a" />
        <rect x={200} y={62} width={14} height={14} fill="#c8907e" />
        {/* Register */}
        <rect x={260} y={54} width={50} height={26} fill="#3a3a3a" />
        <rect x={268} y={60} width={34} height={10} fill="#1a1a1a" />
      </svg>
    </div>
  );
}

function BackgroundPerson({
  shirt,
  hair,
  apron = false,
  walking = false,
  pants = "#34425a",
  facing = "front",
  sipping = false,
}: {
  shirt: string;
  hair: string;
  apron?: boolean;
  walking?: boolean;
  pants?: string;
  facing?: Facing;
  sipping?: boolean;
}) {
  const SKIN = "#e9b890";
  const SHOE = "#1a1a1a";

  // Pseudo-3D head turn via pixel-art eye/mouth shift.
  // "front" → eyes centered. "left"/"right" → eyes shifted that direction
  // (reads as the head turning toward that side). "back" → no face features,
  // and the hair wraps further down to suggest the back of the head.
  const showFace = facing !== "back";
  const eyeShift = facing === "left" ? -2 : facing === "right" ? 2 : 0;

  // Sipping: the right arm bends up so the drink (rendered at SimPerson
  // level) reads as being lifted to the mouth.
  const rightArmHeight = sipping ? 12 : 20;

  return (
    <svg width="44" height="84" viewBox="0 0 44 84" className="pixelated">
      {/* Hair — base shape */}
      <rect x={12} y={4} width={20} height={6} fill={hair} />
      <rect x={10} y={6} width={24} height={6} fill={hair} />
      {/* Head */}
      <rect x={12} y={10} width={20} height={14} fill={SKIN} />
      {showFace ? (
        <>
          {/* Eyes — shift left/right to imply head turn */}
          <rect x={16 + eyeShift} y={16} width={2} height={2} fill="#222" />
          <rect x={26 + eyeShift} y={16} width={2} height={2} fill="#222" />
          {/* Mouth — shifts with the face */}
          <rect x={18 + eyeShift} y={20} width={6} height={1} fill="#5a3a2a" />
        </>
      ) : (
        // Back of head: extend hair down over face area.
        <>
          <rect x={12} y={10} width={20} height={10} fill={hair} />
          <rect x={14} y={20} width={16} height={3} fill={SKIN} opacity={0.7} />
        </>
      )}
      {/* Shirt */}
      <rect x={8} y={24} width={28} height={28} fill={shirt} />
      {apron && <rect x={12} y={28} width={20} height={26} fill="#efe9d3" />}
      {apron && <rect x={12} y={28} width={20} height={2} fill="#8a6a44" />}
      {/* Arms — right arm shortens when sipping (drink lifted to mouth) */}
      <rect x={4} y={24} width={4} height={20} fill={shirt} />
      <rect x={36} y={24} width={4} height={rightArmHeight} fill={shirt} />
      {/* Hips / pants top */}
      <rect x={10} y={52} width={24} height={10} fill={pants} />
      {/* Legs — animated stepping when walking */}
      <g className={walking ? "npc-leg-l" : undefined}>
        <rect x={11} y={62} width={8} height={14} fill={pants} />
        <rect x={10} y={76} width={10} height={4} fill={SHOE} />
      </g>
      <g className={walking ? "npc-leg-r" : undefined}>
        <rect x={25} y={62} width={8} height={14} fill={pants} />
        <rect x={24} y={76} width={10} height={4} fill={SHOE} />
      </g>
    </svg>
  );
}

// Table + two chairs as a single pixel-art unit. 120x72 SVG so chairs flank
// the table at predictable pixel offsets. The seat positions in SIM_TABLES
// (vw-based) are tuned to line up with the chair seats here.
function TableUnit() {
  const WOOD = "#8a6a44";
  const WOOD_DEEP = "#5a3f25";
  const WOOD_DARK = "#6a4a32";
  return (
    <svg width="120" height="72" viewBox="0 0 120 72" className="pixelated">
      {/* Left chair — back + seat */}
      <rect x={4} y={18} width={4} height={28} fill={WOOD_DARK} />
      <rect x={4} y={18} width={4} height={2} fill={WOOD} />
      <rect x={2} y={44} width={16} height={4} fill={WOOD} />
      <rect x={2} y={48} width={16} height={2} fill={WOOD_DEEP} />
      <rect x={4} y={50} width={3} height={14} fill={WOOD_DARK} />
      <rect x={13} y={50} width={3} height={14} fill={WOOD_DARK} />

      {/* Right chair — back + seat (mirrored) */}
      <rect x={112} y={18} width={4} height={28} fill={WOOD_DARK} />
      <rect x={112} y={18} width={4} height={2} fill={WOOD} />
      <rect x={102} y={44} width={16} height={4} fill={WOOD} />
      <rect x={102} y={48} width={16} height={2} fill={WOOD_DEEP} />
      <rect x={104} y={50} width={3} height={14} fill={WOOD_DARK} />
      <rect x={113} y={50} width={3} height={14} fill={WOOD_DARK} />

      {/* Table top — sits between the two chairs */}
      <rect x={22} y={28} width={76} height={10} fill={WOOD} />
      <rect x={22} y={36} width={76} height={4} fill={WOOD_DEEP} />
      {/* Pillar */}
      <rect x={54} y={40} width={12} height={26} fill={WOOD} />
      {/* Base */}
      <rect x={40} y={66} width={40} height={4} fill={WOOD_DEEP} />

      {/* Cup on the table */}
      <rect x={50} y={18} width={14} height={10} fill="#d9d4be" />
      <rect x={50} y={18} width={14} height={2} fill="#7a5a3a" />
      <rect x={64} y={20} width={4} height={6} fill="#d9d4be" />
    </svg>
  );
}

function SteamPuff({ x, delay }: { x: number; delay: number }) {
  return (
    <div
      className="absolute"
      style={{
        left: x + 30,
        bottom: 60,
        width: 8,
        height: 8,
        background: "#ffffff",
        opacity: 0.7,
        animation: "steam 2.4s ease-out infinite",
        animationDelay: `${delay}s`,
        pointerEvents: "none",
      }}
    />
  );
}

function PendantLight({ x }: { x: string }) {
  return (
    <div
      className="absolute"
      style={{ left: x, top: 0, transform: "translateX(-50%)" }}
    >
      <svg width="40" height="80" viewBox="0 0 40 80" className="pixelated">
        <rect x={19} y={0} width={2} height={50} fill="#3a3a3a" />
        <rect x={8} y={50} width={24} height={4} fill="#3a3a3a" />
        <rect x={6} y={54} width={28} height={12} fill="#3a3a3a" />
        <rect x={12} y={66} width={16} height={4} fill="#f4d55c" />
      </svg>
    </div>
  );
}

function PixelPlant({ scale = 1 }: { scale?: number }) {
  return (
    <div style={{ transform: `scale(${scale})`, transformOrigin: "bottom center" }}>
      <svg width="50" height="90" viewBox="0 0 50 90" className="pixelated">
        <rect x={10} y={68} width={30} height={20} fill="#a55a3a" />
        <rect x={10} y={68} width={30} height={4} fill="#7a3e25" />
        <rect x={18} y={40} width={14} height={28} fill="#5a7a4a" />
        <rect x={8} y={30} width={14} height={22} fill="#6b8a52" />
        <rect x={28} y={26} width={14} height={26} fill="#6b8a52" />
        <rect x={14} y={18} width={10} height={18} fill="#7a9a60" />
        <rect x={26} y={14} width={10} height={20} fill="#7a9a60" />
      </svg>
    </div>
  );
}

// =============================================================================
// UI bits
// =============================================================================

function DownloadIcon() {
  return (
    <svg width="12" height="12" viewBox="0 0 12 12" className="pixelated">
      <rect x={5} y={0} width={2} height={6} fill="currentColor" />
      <rect x={3} y={4} width={2} height={2} fill="currentColor" />
      <rect x={7} y={4} width={2} height={2} fill="currentColor" />
      <rect x={2} y={6} width={2} height={2} fill="currentColor" />
      <rect x={8} y={6} width={2} height={2} fill="currentColor" />
      <rect x={0} y={9} width={12} height={2} fill="currentColor" />
    </svg>
  );
}

// =============================================================================
// Pixel character — sits on café chair, slaps every 3s
// =============================================================================

function PixelCharacter() {
  const [slapping, setSlapping] = useState(false);

  useEffect(() => {
    const id = setInterval(() => {
      setSlapping(true);
      window.setTimeout(() => setSlapping(false), 220);
    }, 3000);
    return () => clearInterval(id);
  }, []);

  return (
    <div
      className="absolute left-1/2 -translate-x-1/2 z-30 pointer-events-none"
      style={{ bottom: "8%", width: 240, height: 170 }}
    >
      {/* Inner scale wrapper — anchored to center-bottom so feet stay on floor.
          Hero character is intentionally larger than the café NPCs so the
          slapping demo is the unmistakable focal point of the scene. */}
      <div
        className="absolute inset-0"
        style={{ transform: "scale(1.85)", transformOrigin: "center bottom" }}
      >
        <div className="absolute inset-0 flex items-end justify-center">
          <SeatCafeChair />
        </div>
        {/* Cactus pot on the LEFT side of the bench */}
        <div className="absolute" style={{ left: 8, bottom: 0 }}>
          <PixelCactus />
        </div>
        <div className="absolute inset-x-0 bottom-[18px] flex justify-center">
          <PixelPerson slapping={slapping} />
        </div>
        <PixelImpact visible={slapping} />
      </div>
    </div>
  );
}

function PixelCactus() {
  return (
    <svg width="30" height="56" viewBox="0 0 30 56" className="pixelated">
      {/* Soil */}
      <rect x={6} y={42} width={18} height={3} fill="#3a2818" />
      {/* Terracotta pot */}
      <rect x={5} y={45} width={20} height={10} fill="#a55a3a" />
      <rect x={5} y={45} width={20} height={2} fill="#7a3e25" />
      <rect x={5} y={53} width={20} height={2} fill="#7a3e25" />
      {/* Main stem */}
      <rect x={12} y={10} width={6} height={32} fill="#5a8a3a" />
      <rect x={12} y={10} width={2} height={32} fill="#3a6a25" />
      <rect x={16} y={10} width={2} height={32} fill="#7aa84a" />
      <rect x={12} y={10} width={6} height={2} fill="#7aa84a" />
      {/* Left arm */}
      <rect x={4} y={22} width={8} height={3} fill="#5a8a3a" />
      <rect x={4} y={16} width={3} height={7} fill="#5a8a3a" />
      <rect x={4} y={16} width={1} height={7} fill="#3a6a25" />
      {/* Right arm */}
      <rect x={18} y={26} width={8} height={3} fill="#5a8a3a" />
      <rect x={23} y={18} width={3} height={9} fill="#5a8a3a" />
      <rect x={23} y={18} width={1} height={9} fill="#3a6a25" />
      {/* Spines */}
      <rect x={14} y={18} width={1} height={1} fill="#fff" opacity={0.5} />
      <rect x={15} y={28} width={1} height={1} fill="#fff" opacity={0.5} />
      <rect x={13} y={36} width={1} height={1} fill="#fff" opacity={0.5} />
      <rect x={6} y={18} width={1} height={1} fill="#fff" opacity={0.4} />
      <rect x={24} y={20} width={1} height={1} fill="#fff" opacity={0.4} />
    </svg>
  );
}

function PixelPerson({ slapping }: { slapping: boolean }) {
  const SKIN = "#e9b890";
  const SKIN_SHADE = "#c9956f";
  const HAIR = "#2a1d16";
  const SHIRT = "var(--accent)";
  const SHIRT_DEEP = "#a13a23";
  const PANTS = "#34425a";
  const MAC = "#d9d4be";
  const MAC_DEEP = "#8c8775";
  const MAC_SCREEN = "#3c4350";

  return (
    <svg
      viewBox="0 0 96 110"
      width="96"
      height="110"
      className="pixelated"
      style={{ overflow: "visible" }}
    >
      {/* Hair */}
      <rect x={38} y={8} width={20} height={4} fill={HAIR} />
      <rect x={36} y={10} width={24} height={4} fill={HAIR} />
      {/* Head */}
      <rect x={36} y={14} width={24} height={16} fill={SKIN} />
      <rect x={36} y={14} width={3} height={6} fill={HAIR} />
      <rect x={57} y={14} width={3} height={4} fill={HAIR} />
      {/* Eyes */}
      <rect x={41} y={20} width={3} height={3} fill={HAIR} />
      <rect x={52} y={20} width={3} height={3} fill={HAIR} />
      {/* Cheeks */}
      <rect x={38} y={25} width={2} height={2} fill={SKIN_SHADE} />
      <rect x={56} y={25} width={2} height={2} fill={SKIN_SHADE} />
      {/* Mouth */}
      <rect x={43} y={26} width={6} height={2} fill={HAIR} />
      {/* Neck */}
      <rect x={43} y={30} width={10} height={4} fill={SKIN} />
      {/* Shirt */}
      <rect x={32} y={34} width={32} height={26} fill={SHIRT} />
      <rect x={32} y={56} width={32} height={4} fill={SHIRT_DEEP} />
      {/* Pants */}
      <rect x={34} y={60} width={28} height={22} fill={PANTS} />
      <rect x={47} y={68} width={2} height={14} fill="#1d2638" />
      {/* Legs */}
      <rect x={35} y={82} width={9} height={14} fill={PANTS} />
      <rect x={52} y={82} width={9} height={14} fill={PANTS} />
      {/* Shoes */}
      <rect x={31} y={96} width={13} height={6} fill={HAIR} />
      <rect x={52} y={96} width={13} height={6} fill={HAIR} />
      {/* MacBook */}
      <rect x={24} y={56} width={48} height={6} fill={MAC_DEEP} />
      <rect x={26} y={48} width={44} height={10} fill={MAC} />
      <rect x={29} y={50} width={38} height={7} fill={MAC_SCREEN} />
      <rect x={48} y={56} width={4} height={1} fill="#ffffff" opacity={0.5} />
      {/* Left arm */}
      <rect x={24} y={36} width={8} height={20} fill={SHIRT} />
      <rect x={22} y={54} width={10} height={6} fill={SKIN} />
      {/* Right arm — slaps */}
      <g
        style={{
          transformOrigin: "68px 38px",
          transform: slapping ? "rotate(55deg)" : "rotate(-8deg)",
          transition: slapping
            ? "transform 70ms cubic-bezier(0.5, 0, 0.75, 0)"
            : "transform 220ms cubic-bezier(0.16, 1, 0.3, 1)",
        }}
      >
        <rect x={64} y={36} width={8} height={20} fill={SHIRT} />
        <rect x={64} y={54} width={10} height={6} fill={SKIN} />
      </g>
    </svg>
  );
}

function PixelImpact({ visible }: { visible: boolean }) {
  const angles = [0, 45, 90, 135, 180, 225, 270, 315];
  return (
    <div
      className="absolute pointer-events-none"
      style={{
        left: "50%",
        bottom: "62px",
        width: 0,
        height: 0,
        opacity: visible ? 1 : 0,
        transition: visible ? "opacity 40ms linear" : "opacity 180ms ease-out",
      }}
    >
      <svg
        width="120"
        height="120"
        viewBox="-60 -60 120 120"
        className="pixelated"
        style={{
          position: "absolute",
          left: -60,
          top: -60,
          transform: visible ? "scale(1)" : "scale(0.7)",
          transition: "transform 140ms cubic-bezier(0.16, 1, 0.3, 1)",
        }}
      >
        {angles.map((deg) => {
          const rad = (deg * Math.PI) / 180;
          const inner = 22;
          const outer = 42;
          return (
            <line
              key={deg}
              x1={Math.cos(rad) * inner}
              y1={Math.sin(rad) * inner}
              x2={Math.cos(rad) * outer}
              y2={Math.sin(rad) * outer}
              stroke="var(--accent)"
              strokeWidth="3"
              strokeLinecap="square"
            />
          );
        })}
      </svg>
    </div>
  );
}

function SeatCafeChair() {
  return (
    <svg width="170" height="66" viewBox="0 0 170 66" className="pixelated">
      <rect x={30} y={0} width={110} height={6} fill="#8c6a52" />
      <rect x={30} y={6} width={6} height={16} fill="#8c6a52" />
      <rect x={134} y={6} width={6} height={16} fill="#8c6a52" />
      <rect x={18} y={22} width={134} height={10} fill="#a07a5e" />
      <rect x={18} y={30} width={134} height={4} fill="#6f4f3a" />
      <rect x={26} y={34} width={6} height={26} fill="#8c6a52" />
      <rect x={138} y={34} width={6} height={26} fill="#8c6a52" />
    </svg>
  );
}
