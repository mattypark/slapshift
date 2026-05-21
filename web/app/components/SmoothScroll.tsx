"use client";

// Buttery smooth wheel scroll for the whole site (Lenis), wired into
// GSAP's ticker so ScrollTrigger reveals stay in sync. Wrap once at the
// root layout. Renders nothing of its own.

import { useEffect } from "react";
import Lenis from "lenis";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";

if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger);
}

export default function SmoothScroll({
  children,
}: {
  children: React.ReactNode;
}) {
  useEffect(() => {
    const lenis = new Lenis({
      // Lerp mode — every frame we close 8% of the remaining distance to
      // the target. Frame-rate independent, no easing curve, no
      // half-frame-off micro-stutter. Lower = slower/glassier, higher =
      // snappier. 0.08 is the matthewnpark.com / premium-portfolio feel.
      lerp: 0.08,
      smoothWheel: true,
      // Tame trackpad fling slightly so it doesn't overshoot the target.
      wheelMultiplier: 1,
    });

    // Drive ScrollTrigger off Lenis's scroll events so reveals fire at the
    // right moment instead of fighting native scroll.
    lenis.on("scroll", ScrollTrigger.update);

    // Drive Lenis off GSAP's ticker so they share a single rAF loop.
    const tick = (time: number) => lenis.raf(time * 1000);
    gsap.ticker.add(tick);
    gsap.ticker.lagSmoothing(0);

    return () => {
      gsap.ticker.remove(tick);
      lenis.destroy();
    };
  }, []);

  return <>{children}</>;
}
