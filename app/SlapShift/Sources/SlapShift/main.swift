// SlapShift — entrypoint.
//
// Menu-bar app, no Dock icon (.accessory activation policy). We avoid SwiftUI
// @main + MenuBarExtra because we need fine-grained control over the status
// item icon (e.g. flash-on-slap before the action fires).
//
// Layering (top to bottom):
//
//   MotionPoller  (840Hz IOKit reports)
//        │
//        ▼  (x, y, z, mag, timestamp)
//   SlapClassifier  (peak detection + 1/2/3 disambiguation, 400ms window)
//        │
//        ▼  SlapEvent { count: 1|2|3, peakG }
//   AppDelegate  (route slap → mode → executor)
//        │
//        ▼
//   ActionExecutor  (NSWorkspace open/quit, URL launch, `shortcuts run` for Focus)

import AppKit

// AppDelegate is @MainActor; this entire top-level file runs on the main thread
// at process start, but Swift's concurrency checker can't infer that. Wrap the
// startup sequence in a MainActor.assumeIsolated block to satisfy it.
MainActor.assumeIsolated {
    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    NSApplication.shared.setActivationPolicy(.accessory)
    NSApplication.shared.run()
}
