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
    // 2026-05-22 retune: real-world slaps from Matthew measured well below the
    // 1.06g floor we calibrated against — soft palm-rest slaps were missing
    // entirely. Dropped to 1.04g (still ~8σ above the 0.005g idle drift) and
    // widened the multi-slap window so a comfortable triple-tap rhythm of
    // ~180ms between slaps fits with margin.
    var slapThresholdG: Double = 1.025      // very forgiving; idle noise floor ≈ 1.0±0.005
    var releaseThresholdG: Double = 1.015   // hysteresis: must dip below this to re-arm rising edge
    var windowSeconds: Double = 0.85        // 3 slaps at 250ms apart = 500ms + 350ms grace
    var minInterSlapSeconds: Double = 0.10  // floor for counting two distinct slaps
    var cooldownSeconds: Double = 0.15      // dead time after emit
    var maxCount: Int = 3

    var onSlap: ((SlapEvent) -> Void)?

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
        reset()
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
