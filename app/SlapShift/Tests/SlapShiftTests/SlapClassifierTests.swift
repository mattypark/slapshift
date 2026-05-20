// Tests for SlapClassifier.
//
// Strategy: feed synthetic sample streams, force the emit timer via `_forceEmitForTesting`,
// and assert on count + peakG. We don't test the IOKit poller (no fake hardware) and we don't
// test the action executor (would require launching real apps).

import XCTest
@testable import SlapShift

final class SlapClassifierTests: XCTestCase {

    private var classifier: SlapClassifier!
    private var events: [SlapEvent] = []

    override func setUp() {
        super.setUp()
        classifier = SlapClassifier()
        events = []
        classifier.onSlap = { [weak self] in self?.events.append($0) }
    }

    // MARK: - Helpers

    private func sample(t: TimeInterval, mag: Double) -> MotionSample {
        MotionSample(timestamp: t, x: 0, y: 0, z: mag, magnitude: mag)
    }

    /// Feed a synthetic slap cluster: idle → above threshold for `peakSamples` × 1.19ms → idle.
    /// At 840Hz native, 30 samples ≈ 35ms which matches measured palm-slap shape.
    private func injectSlap(startT: TimeInterval, peakG: Double, peakSamples: Int = 30) -> TimeInterval {
        let dt = 1.0 / 840.0
        var t = startT
        // pre-roll idle so the previous-magnitude state is correctly below threshold
        for _ in 0..<5 { classifier.ingest(sample(t: t, mag: 0.98)); t += dt }
        // rising edge
        classifier.ingest(sample(t: t, mag: peakG)); t += dt
        // sustain
        for _ in 0..<(peakSamples - 1) { classifier.ingest(sample(t: t, mag: peakG * 0.97)); t += dt }
        // falling
        for _ in 0..<5 { classifier.ingest(sample(t: t, mag: 0.98)); t += dt }
        return t
    }

    // MARK: - Single slap

    func test_singleSlap_emitsCountOne() {
        _ = injectSlap(startT: 0.0, peakG: 1.12)
        classifier._forceEmitForTesting()

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.count, 1)
        XCTAssertEqual(events.first?.peakG ?? 0, 1.12, accuracy: 0.01)
    }

    // MARK: - Two slaps within window

    func test_twoSlapsWithinWindow_emitsCountTwo() {
        var t = injectSlap(startT: 0.0, peakG: 1.10)
        t += 0.18  // 180ms — well inside 400ms window, well outside 100ms min-gap
        _ = injectSlap(startT: t, peakG: 1.15)
        classifier._forceEmitForTesting()

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.count, 2)
        XCTAssertEqual(events.first?.peakG ?? 0, 1.15, accuracy: 0.01)
    }

    func test_threeSlapsWithinWindow_emitsCountThree() {
        var t = injectSlap(startT: 0.0, peakG: 1.09)
        t += 0.12
        t = injectSlap(startT: t, peakG: 1.13)
        t += 0.12
        _ = injectSlap(startT: t, peakG: 1.10)
        classifier._forceEmitForTesting()

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.count, 3)
    }

    // MARK: - Beyond max count clamps

    func test_fourSlapsClampsToThree() {
        var t = injectSlap(startT: 0.0, peakG: 1.10)
        t += 0.08
        t = injectSlap(startT: t, peakG: 1.10)
        t += 0.08
        t = injectSlap(startT: t, peakG: 1.10)
        t += 0.08
        _ = injectSlap(startT: t, peakG: 1.10)
        classifier._forceEmitForTesting()

        XCTAssertEqual(events.first?.count, 3)
    }

    // MARK: - Sub-threshold is ignored

    func test_subThresholdMagnitude_doesNotFire() {
        // 1.04g is above gravity but below 1.06g threshold — typing-thump territory
        _ = injectSlap(startT: 0.0, peakG: 1.04)
        classifier._forceEmitForTesting()

        XCTAssertEqual(events.count, 0)
    }

    // MARK: - Same slap's trailing edge does not double-count

    func test_sustainedCluster_countsAsOne() {
        // A single 50ms cluster should count as one slap, not many.
        // injectSlap already produces sustained samples; the rising-edge detector should fire once.
        _ = injectSlap(startT: 0.0, peakG: 1.20, peakSamples: 50)
        classifier._forceEmitForTesting()

        XCTAssertEqual(events.first?.count, 1)
    }
}
