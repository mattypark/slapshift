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
                        Text(String(format: "%.2fg threshold", prefs.slapThresholdG))
                            .font(.slapMeta(size: 11))
                            .foregroundStyle(Brand.mute)
                    }
                    Slider(value: $prefs.slapThresholdG, in: 1.02...1.20, step: 0.01) {
                        Text("Threshold")
                    } minimumValueLabel: {
                        Text("Soft").font(.slapMeta(size: 10)).foregroundStyle(Brand.whisper)
                    } maximumValueLabel: {
                        Text("Firm").font(.slapMeta(size: 10)).foregroundStyle(Brand.whisper)
                    }
                    .tint(Brand.accent)
                    Text("Lower = easier to trigger but more false positives from typing. Calibrated default 1.06g.")
                        .font(.slapBody(size: 11))
                        .foregroundStyle(Brand.mute)
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
                    Slider(value: $prefs.slapWindowSeconds, in: 0.20...1.00, step: 0.05) {
                        Text("Window")
                    } minimumValueLabel: {
                        Text("Fast").font(.slapMeta(size: 10)).foregroundStyle(Brand.whisper)
                    } maximumValueLabel: {
                        Text("Relaxed").font(.slapMeta(size: 10)).foregroundStyle(Brand.whisper)
                    }
                    .tint(Brand.accent)
                    Text("How long to wait after the first slap before firing the mode. Shorter = quicker action but you have to slap faster for 2/3. Default 400ms.")
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
