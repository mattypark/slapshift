"use client";

// Slide-up + fade-in on scroll. Wrap any block that should animate in
// once it enters the viewport.
//
//   <Reveal>            ...default: 40px up, 0.9s, no delay
//   <Reveal delay={0.1} y={60} duration={1.1}>
//
// Plays once. Respects prefers-reduced-motion (no animation, just visible).

import { useEffect, useRef } from "react";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";

if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger);
}

type Props = {
  children: React.ReactNode;
  delay?: number;
  y?: number;
  duration?: number;
  // For elements that should reveal earlier/later relative to the viewport.
  // Default fires when the top of the element hits 85% down the viewport.
  start?: string;
};

export default function Reveal({
  children,
  delay = 0,
  y = 40,
  duration = 0.9,
  start = "top 85%",
}: Props) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduce) {
      // No animation — just leave it visible. Setting opacity/y explicitly
      // here in case CSS ever ships a starting hidden state.
      gsap.set(el, { opacity: 1, y: 0 });
      return;
    }

    const ctx = gsap.context(() => {
      gsap.fromTo(
        el,
        { y, opacity: 0 },
        {
          y: 0,
          opacity: 1,
          duration,
          delay,
          ease: "power3.out",
          scrollTrigger: {
            trigger: el,
            start,
            // Play once on first entry, never reverse.
            toggleActions: "play none none none",
          },
        },
      );
    }, el);

    return () => ctx.revert();
  }, [delay, y, duration, start]);

  // Start hidden so there's no flash of unstyled content before GSAP
  // takes over on mount.
  return (
    <div ref={ref} style={{ opacity: 0, willChange: "transform, opacity" }}>
      {children}
    </div>
  );
}
