// SettingsView — root of the settings window.
//
// Visual language: matches slapshift.app + the onboarding window. Cream paper
// surface, ink text, Newsreader serif headlines, monospace body, red accent.
// We force the window into .aqua appearance (see SettingsWindow.swift) so the
// brand reads consistently regardless of the user's system theme.
//
// Layout:
//   ┌──────────────────────────────────────┐
//   │  [S] SlapShift                       │  ← brand logo + wordmark
//   │      Slap your MacBook to switch...  │
//   ├──────────────────────────────────────┤
//   │  General                             │
//   │    Sensitivity  ⊖━━━━●━━━⊕ 1.06g     │
//   │    [▌▌▌▌▌▌·····│······]   live meter │  ← Discord-style audio check
//   │    Slap window  ⊖━━━●━━━━⊕ 400ms     │
//   │    Launch at login                 ☑ │
//   ├──────────────────────────────────────┤
//   │  Modes                               │
//   │    [Coding]     [Apply]   [WindDown] │  ← editor cards
//   └──────────────────────────────────────┘

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var modeStore: ModeStore
    @EnvironmentObject var prefs: AppPreferences
    @EnvironmentObject var motionMonitor: MotionMonitor

    var body: some View {
        ZStack {
            Brand.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    generalSection
                    modesSection
                    footer
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
            }
        }
        .frame(minWidth: 560, idealWidth: 640, minHeight: 600, idealHeight: 780)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            BrandLogo(height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text("SlapShift")
                    .font(.slapDisplay(size: 30, weight: .bold))
                    .foregroundStyle(Brand.ink)
                Text("Slap your MacBook to switch modes.")
                    .font(.slapBody(size: 12))
                    .foregroundStyle(Brand.mute)
            }
            Spacer()
        }
        .padding(.bottom, 4)
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("General")

            // Sensitivity card.
            paperCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label {
                            Text("Sensitivity")
                                .font(.system(size: 14, weight: .semibold, design: .serif))
                                .foregroundStyle(Brand.ink)
                        } icon: {
                            Image(systemName: "waveform")
                                .foregroundStyle(Brand.accent)
                        }
                        Spacer()
                        Text(String(format: "%.3fg threshold", prefs.slapThresholdG))
                            .font(.slapMeta(size: 11))
                            .foregroundStyle(Brand.mute)
                    }
                    Slider(value: $prefs.slapThresholdG, in: 1.01...1.20, step: 0.005) {
                        Text("Threshold")
                    } minimumValueLabel: {
                        Text("Soft").font(.slapMeta(size: 10)).foregroundStyle(Brand.whisper)
                    } maximumValueLabel: {
                        Text("Firm").font(.slapMeta(size: 10)).foregroundStyle(Brand.whisper)
                    }
                    .tint(Brand.accent)
                    Text("Lower = easier to trigger but more false positives from typing. Default \(String(format: "%.3fg", AppPreferences.defaultThresholdG)).")
                        .font(.slapBody(size: 11))
                        .foregroundStyle(Brand.mute)

                    // Live meter — Discord-style. The bar strip shows the
                    // current accelerometer magnitude, with a vertical red
                    // line marking the current threshold. Slap your MacBook
                    // and you'll see the bars surge past the threshold and
                    // pulse red as a slap fires.
                    SensitivityMeter(
                        magnitude: motionMonitor.liveMagnitude,
                        recentPeak: motionMonitor.recentPeakG,
                        threshold: prefs.slapThresholdG,
                        lastSlapAt: motionMonitor.lastSlapAt,
                        lastSlapCount: motionMonitor.lastSlapCount
                    )
                    .padding(.top, 4)
                }
            }

            // Slap-window card.
            paperCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label {
                            Text("Slap window")
                                .font(.system(size: 14, weight: .semibold, design: .serif))
                                .foregroundStyle(Brand.ink)
                        } icon: {
                            Image(systemName: "timer")
                                .foregroundStyle(Brand.accent)
                        }
                        Spacer()
                        Text(String(format: "%.0f ms", prefs.slapWindowSeconds * 1000))
                            .font(.slapMeta(size: 11))
                            .foregroundStyle(Brand.mute)
                    }
                    Slider(value: $prefs.slapWindowSeconds, in: 0.20...1.20, step: 0.05) {
                        Text("Window")
                    } minimumValueLabel: {
                        Text("Fast").font(.slapMeta(size: 10)).foregroundStyle(Brand.whisper)
                    } maximumValueLabel: {
                        Text("Relaxed").font(.slapMeta(size: 10)).foregroundStyle(Brand.whisper)
                    }
                    .tint(Brand.accent)
                    Text("How long to wait after the first slap before firing the mode. Shorter = quicker action but you have to slap faster for 2/3. Default \(String(format: "%.0f ms", AppPreferences.defaultWindowSeconds * 1000)).")
                        .font(.slapBody(size: 11))
                        .foregroundStyle(Brand.mute)
                }
            }

            // Launch-at-login row.
            paperCard {
                HStack {
                    Label {
                        Text("Launch SlapShift at login")
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .foregroundStyle(Brand.ink)
                    } icon: {
                        Image(systemName: "power")
                            .foregroundStyle(Brand.accent)
                    }
                    Spacer()
                    Toggle("", isOn: $prefs.launchAtLogin)
                        .toggleStyle(.switch)
                        .tint(Brand.accent)
                        .labelsHidden()
                }
            }
        }
    }

    private var modesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Modes")

            ForEach(modeStore.modes.sorted(by: { $0.slapCount < $1.slapCount })) { mode in
                ModeEditorView(modeID: mode.id)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Modes save automatically. Stored at:")
                .font(.slapBody(size: 11))
                .foregroundStyle(Brand.mute)
            Text("~/Library/Application Support/SlapShift/modes.json")
                .font(.slapMeta(size: 10))
                .foregroundStyle(Brand.whisper)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.slapTitle(size: 20))
            .foregroundStyle(Brand.ink)
            .tracking(0.4)
    }

    /// Cream-paper card surface with hairline rule. Matches the website's
    /// content blocks — same shape as Onboarding's SelectableCard.
    private func paperCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Brand.cream)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Brand.rule.opacity(0.5), lineWidth: 1)
            )
    }
}

// MARK: - SensitivityMeter
//
// Discord-style "is my mic picking up audio" widget, ported to slap-detection.
// Renders 40 vertical bars. Each bar is lit if its position-along-the-scale
// is below the current normalized magnitude. A vertical red rule marks the
// current threshold so the user can dial sensitivity by feel: "I want the
// threshold to sit right where my casual slap peaks land."
//
// The "you just slapped" pulse: when MotionMonitor.lastSlapAt updates we
// flash the whole bar strip with a red overlay for ~600ms, with a small
// label underneath stating which count was detected ("1 slap detected").
//
// Magnitude scale: 1.00g (idle gravity) → 1.50g (a hard slap). Anything
// above 1.50g pegs the meter at full. The threshold slider's range is
// 1.01...1.20 so the red rule lives within the first ~40% of the strip.

private struct SensitivityMeter: View {
    let magnitude: Double
    let recentPeak: Double
    let threshold: Double
    let lastSlapAt: Date?
    let lastSlapCount: Int

    /// Magnitude span the strip visualizes. Anything outside is clamped to
    /// the edges. 0.8g floor shows the sub-gravity dip on a real slap
    /// rebound (the discriminator that filters shake); 1.5g ceiling covers a
    /// firm slap on Apple Silicon laptops without wasting bar real estate.
    private let scaleMin: Double = 0.80
    private let scaleMax: Double = 1.50

    private let barCount: Int = 40

    private var normalizedMagnitude: Double {
        normalize(magnitude)
    }

    private var normalizedThreshold: Double {
        normalize(threshold)
    }

    private var normalizedPeak: Double {
        normalize(recentPeak)
    }

    private func normalize(_ g: Double) -> Double {
        let raw = (g - scaleMin) / (scaleMax - scaleMin)
        return min(max(raw, 0), 1)
    }

    /// True for ~600ms after a slap fires.
    private var isPulsing: Bool {
        guard let t = lastSlapAt else { return false }
        return Date().timeIntervalSince(t) < 0.6
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Bar strip.
                    HStack(spacing: 2) {
                        ForEach(0..<barCount, id: \.self) { i in
                            bar(at: i)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Threshold reference line — a vertical red rule the
                    // user can match their slap peak against. Pinned to its
                    // normalized horizontal position.
                    Rectangle()
                        .fill(Brand.accent)
                        .frame(width: 2)
                        .offset(x: geo.size.width * normalizedThreshold)
                        .opacity(0.85)

                    // Recent-peak indicator — a thin ink tick that marks
                    // the highest magnitude observed in the last ~1.5s.
                    Rectangle()
                        .fill(Brand.ink.opacity(0.55))
                        .frame(width: 1)
                        .offset(x: geo.size.width * normalizedPeak)
                }
            }
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Brand.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Brand.rule.opacity(0.6), lineWidth: 1)
            )
            .overlay(
                // Red pulse overlay when a slap was just detected.
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Brand.accent.opacity(isPulsing ? 0.18 : 0))
                    .animation(.easeOut(duration: 0.45), value: isPulsing)
            )

            // Caption row: live g + last-slap result.
            HStack(spacing: 6) {
                Text(String(format: "Live %.3fg · peak %.2fg", magnitude, recentPeak))
                    .font(.slapMeta(size: 10))
                    .foregroundStyle(Brand.mute)
                Spacer()
                if let _ = lastSlapAt, isPulsing {
                    Text("\(lastSlapCount) slap\(lastSlapCount == 1 ? "" : "s") detected")
                        .font(.slapMeta(size: 10))
                        .foregroundStyle(Brand.accent)
                        .transition(.opacity)
                } else if lastSlapAt != nil {
                    Text("Last: \(lastSlapCount) slap\(lastSlapCount == 1 ? "" : "s")")
                        .font(.slapMeta(size: 10))
                        .foregroundStyle(Brand.whisper)
                } else {
                    Text("Slap your MacBook to test")
                        .font(.slapMeta(size: 10))
                        .foregroundStyle(Brand.whisper)
                }
            }
        }
    }

    @ViewBuilder
    private func bar(at index: Int) -> some View {
        let position = Double(index) / Double(barCount - 1)
        let lit = position <= normalizedMagnitude
        let crossed = position <= normalizedThreshold
        // Bars below the threshold light up in a calm sand tone; bars past
        // the threshold light up red to telegraph "this would fire a slap."
        let color: Color = !lit
            ? Brand.rule.opacity(0.35)
            : (crossed ? Brand.hill.opacity(0.85) : Brand.accent)
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
