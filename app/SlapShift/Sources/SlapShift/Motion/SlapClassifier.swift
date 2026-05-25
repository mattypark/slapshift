// SlapClassifier — turn a stream of 840Hz magnitude samples into discrete SlapEvents.
//
// Calibration source: SlapSpike v2 on 2026-05-19. Numbers measured on Matthew's M-series
// MacBook with palm-rest slaps (the softest realistic gesture).
//
//   IDLE_BASELINE_G ≈ 0.98       (gravity, drift ±0.005g)
//   PALM_SLAP_PEAK  ≈ 1.05-1.12  (cluster spans ~30-50ms, ~25-40 samples @ 840Hz)
//   INTER_SLAP_GAP  ≈ 1.2s       (between consecutive deliberate slaps)
//
// State machine:
//
//   IDLE ──peak≥thresh──▶ COUNTING(count=1) ──peak after minGap──▶ COUNTING(count++)
//      ▲                       │
//      │                  windowExpires(400ms)
//      │                       │
//      └────emit(count)────────┘  COOLDOWN(150ms) ──▶ IDLE
//
// Rules:
//   - A "peak" is a rising edge: previous sample below threshold AND current sample at or above
//   - Min 100ms between counted slaps (otherwise the trailing samples of one slap = a second slap)
//   - Window of 400ms from the FIRST slap to count subsequent slaps
//   - Max 3 slaps tracked (anything beyond is still "3 slaps")
//   - 150ms post-emit cooldown so we don't double-fire on the next idle tick

import Foundation

struct SlapEvent {
    let count: Int               // 1, 2, or 3
    let peakG: Double            // max magnitude observed across the cluster
    let timestamp: TimeInterval  // when the FIRST slap of the count fired
}

final class SlapClassifier {

    // Tuning constants. Public so a settings UI can later drive them via a sensitivity slider.
    //
    // 2026-05-24 retune (third pass): the 1.025g threshold + 1.015g release was
    // catching chassis ring (one slap → 3 counted) AND any general laptop
    // motion (picking it up, shake → counted as slap). Two root causes:
    //   1. Threshold too close to gravity baseline (1.0g) — shake oscillates
    //      between ~0.85g and ~1.20g, easily clearing 1.025g.
    //   2. Release threshold ABOVE gravity baseline — a slap rings the chassis
    //      at ~30-50ms period, dipping briefly below 1.015g between peaks, so
    //      the rising-edge detector re-armed and counted the next ring crest
    //      as a separate slap.
    // Fix: raise trigger above any plausible shake peak, and demand a real
    // sub-gravity dip (chassis bouncing back / wrist lift) before re-arming.
    // A genuine slap produces a brief free-fall-like dip; sustained shake does
    // not, so this is also a slap-vs-shake discriminator.
    // 2026-05-24 retune (fifth pass): user reported even firm slaps were not
    // reaching 1.08g — actual palm-rest slaps peak ~1.02-1.05g on their Mac,
    // so the meter showed motion but never tripped. Dropped trigger to 1.03g
    // (just above idle drift floor of ~1.005g ± 0.005g). The sub-gravity
    // release threshold (0.92g) remains the primary shake discriminator: a
    // genuine slap rebounds the chassis below gravity for a frame; sustained
    // shake oscillates near gravity but rarely dips that low.
    var slapThresholdG: Double = 1.03       // soft tap reaches this; idle drift (~1.005g) does not
    var releaseThresholdG: Double = 0.92    // sub-gravity dip = slap signature; shake stays above
    var windowSeconds: Double = 0.85        // 3 slaps at 250ms apart = 500ms + 350ms grace
    var minInterSlapSeconds: Double = 0.22  // floor for counting two distinct slaps (was 0.10 — caught chassis ring)
    var cooldownSeconds: Double = 0.20      // dead time after emit
    var maxCount: Int = 3

    var onSlap: ((SlapEvent) -> Void)?

    /// Fires every time a slap is added to the in-progress count, BEFORE the
    /// window closes and emit() runs. Used by the onboarding meter to show
    /// "Slap 1 → Slap 2 → Slap 3" live as the user does them, instead of
    /// waiting for the full window to expire. Passes (currentCount,
    /// secondsRemainingInWindow). When window closes, fires once more with
    /// count=0 and 0s so the UI can clear.
    var onProgress: ((Int, TimeInterval) -> Void)?

    // State
    private var count: Int = 0
    private var firstSlapAt: TimeInterval = 0
    private var lastSlapAt: TimeInterval = 0
    private var lastEmitAt: TimeInterval = -.infinity
    private var peakG: Double = 0
    private var pendingTimer: DispatchSourceTimer?
    // Armed = ready to trigger on the next rising edge. Disarms on trigger,
    // re-arms only when the signal dips below releaseThresholdG. This gives
    // the rising-edge detector hysteresis so a noisy plateau around the
    // threshold doesn't produce phantom slaps or, conversely, fail to retrigger.
    private var armed: Bool = true

    func ingest(_ sample: MotionSample) {
        let now = sample.timestamp
        let mag = sample.magnitude

        // Cooldown gate
        if now - lastEmitAt < cooldownSeconds { return }

        // Track peak magnitude across the active counting window so the emitted event reports honest force
        if count > 0 && mag > peakG { peakG = mag }

        // Re-arm once the signal drops back below the release threshold.
        if !armed && mag < releaseThresholdG {
            armed = true
        }

        // Trigger only on a fresh rising edge while armed.
        guard armed && mag >= slapThresholdG else { return }
        armed = false
        // Diagnostic — every rising-edge trigger prints regardless of whether
        // it ends up counted. Lets the user see in Console.app whether their
        // slap is even crossing the threshold (the most common bug class).
        print(String(format: "[slap] edge mag=%.3fg count-so-far=%d", mag, count))

        if count == 0 {
            // First slap → start window
            count = 1
            firstSlapAt = now
            lastSlapAt = now
            peakG = mag
            scheduleEmit(at: firstSlapAt + windowSeconds)
        } else {
            // Subsequent slap candidate → must be > minInterSlapSeconds after last counted one
            guard now - lastSlapAt >= minInterSlapSeconds else { return }
            guard now - firstSlapAt <= windowSeconds else {
                // Late edge — window already closed. Should not happen because timer would have
                // fired, but handle defensively.
                return
            }
            count = min(count + 1, maxCount)
            lastSlapAt = now
        }
        let remaining = max(0, (firstSlapAt + windowSeconds) - now)
        onProgress?(count, remaining)
    }

    private func scheduleEmit(at deadline: TimeInterval) {
        pendingTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + windowSeconds)
        timer.setEventHandler { [weak self] in self?.emitNow() }
        pendingTimer = timer
        timer.resume()
    }

    private func emitNow() {
        guard count > 0 else { return }
        let event = SlapEvent(count: count, peakG: peakG, timestamp: firstSlapAt)
        lastEmitAt = firstSlapAt + windowSeconds
        // Diagnostic — every classified cluster prints to Console.app. Lets a
        // remote tester read off the peak g their slap actually produced so we
        // can retune the threshold per-hardware without guessing.
        print(String(format: "[slap] count=%d peakG=%.3f (threshold=%.2fg release=%.2fg)",
                     event.count, event.peakG, slapThresholdG, releaseThresholdG))
        reset()
        // Tell the meter the window closed so it can clear "Slap N" indicator.
        onProgress?(0, 0)
        onSlap?(event)
    }

    private func reset() {
        count = 0
        peakG = 0
        firstSlapAt = 0
        lastSlapAt = 0
        armed = true
        pendingTimer?.cancel()
        pendingTimer = nil
    }

    // MARK: - Test seam
    //
    // Tests drive the classifier with a synthetic sample stream and force window expiry
    // without waiting on a real DispatchSourceTimer. Production code does not call this.
    func _forceEmitForTesting() { emitNow() }
}
