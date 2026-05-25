// MotionMonitor — live meter for the settings UI.
//
// Discord-style audio-check equivalent for the accelerometer: publishes the
// current magnitude (smoothed) and the timestamp of the last emitted slap.
//
// Decoupled from SlapClassifier on purpose: the classifier needs raw samples
// at full rate for rising-edge detection, the meter only needs ~30Hz of
// smoothed magnitude for UI. AppDelegate forks the motion stream so both
// consumers get fed without one starving the other.

import Combine
import Foundation

@MainActor
final class MotionMonitor: ObservableObject {

    /// Smoothed instantaneous magnitude in g. Throttled to ~30Hz for UI.
    @Published private(set) var liveMagnitude: Double = 1.0

    /// Peak magnitude observed in the last 1.5 seconds. Drives the
    /// "you just hit X g" readout under the bar strip.
    @Published private(set) var recentPeakG: Double = 1.0

    /// Wall-clock timestamp of the most recently emitted SlapEvent. The
    /// meter view animates a red pulse for ~600ms after this fires.
    @Published private(set) var lastSlapAt: Date? = nil

    /// Count of the most recent slap (1/2/3) so the meter can label the pulse.
    @Published private(set) var lastSlapCount: Int = 0

    /// In-progress count of slaps WITHIN the active multi-slap window. Updates
    /// live as the user slaps (1 → 2 → 3) before the window closes and the
    /// final SlapEvent fires. Resets to 0 the moment emit() runs. Drives the
    /// onboarding meter's live "Slap 2/3" indicator.
    @Published private(set) var inProgressCount: Int = 0

    /// Wall-clock deadline when the active multi-slap window closes. nil
    /// when no window is open. The meter uses this to draw a shrinking
    /// time-remaining bar.
    @Published private(set) var windowEndsAt: Date? = nil

    private let smoothingAlpha: Double = 0.25
    private var smoothed: Double = 1.0

    private let uiUpdateInterval: TimeInterval = 1.0 / 30.0
    private var lastPublishedAt: TimeInterval = 0

    private let peakWindowSeconds: TimeInterval = 1.5
    private var peakObservedAt: TimeInterval = 0

    /// Feed every motion sample here. Cheap: smoothing + decimation keeps
    /// SwiftUI from being asked to redraw 840 times per second.
    func ingest(_ sample: MotionSample) {
        smoothed = (smoothingAlpha * sample.magnitude) + ((1.0 - smoothingAlpha) * smoothed)

        let now = sample.timestamp
        if sample.magnitude > recentPeakG || (now - peakObservedAt) > peakWindowSeconds {
            recentPeakG = sample.magnitude
            peakObservedAt = now
        }

        guard (now - lastPublishedAt) >= uiUpdateInterval else { return }
        lastPublishedAt = now
        liveMagnitude = smoothed
    }

    /// Called by AppDelegate every time SlapClassifier emits a SlapEvent.
    /// Drives the red pulse animation in the meter view.
    func recordSlap(_ event: SlapEvent) {
        lastSlapAt = Date()
        lastSlapCount = event.count
    }

    /// Called by SlapClassifier on every count increment AND on emit (count=0).
    /// Lets the onboarding meter render "Slap 1 → 2 → 3" live.
    /// `windowSeconds` is how long from NOW until the window closes (the
    /// classifier already computed deadline-firstSlap, so we just project it
    /// onto wall-clock from current Date()).
    func recordProgress(count: Int, secondsUntilDeadline: TimeInterval) {
        inProgressCount = count
        if count == 0 {
            windowEndsAt = nil
        } else {
            windowEndsAt = Date().addingTimeInterval(secondsUntilDeadline)
        }
    }
}
