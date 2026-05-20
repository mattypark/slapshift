// SettingsView — root of the settings window.
//
// Layout:
//   ┌──────────────────────────────────────┐
//   │  SlapShift  · listening               │  ← header w/ status pill
//   ├──────────────────────────────────────┤
//   │  General                              │
//   │    Sensitivity  ⊖━━━━●━━━⊕ 1.06g      │
//   │    Launch at login                  ☑ │
//   ├──────────────────────────────────────┤
//   │  Mode: 1 slap (Coding)            ▼  │  ← editor cards (collapsible)
//   │  Mode: 2 slaps (Apply)            ▼  │
//   │  Mode: 3 slaps (Wind Down)        ▼  │
//   └──────────────────────────────────────┘

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var modeStore: ModeStore
    @EnvironmentObject var prefs: AppPreferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                generalSection
                modesSection
                footer
            }
            .padding(24)
        }
        .frame(minWidth: 560, idealWidth: 640, minHeight: 600, idealHeight: 780)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 32))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("SlapShift").font(.largeTitle.weight(.bold))
                Text("Slap your MacBook to switch modes")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            Spacer()
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General").font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Sensitivity", systemImage: "waveform")
                    Spacer()
                    Text(String(format: "%.2fg threshold", prefs.slapThresholdG))
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
                Slider(value: $prefs.slapThresholdG, in: 1.02...1.20, step: 0.01) {
                    Text("Threshold")
                } minimumValueLabel: {
                    Text("Soft").font(.caption2).foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("Firm").font(.caption2).foregroundColor(.secondary)
                }
                Text("Lower = easier to trigger but more false positives from typing. Calibrated default 1.06g.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)

            HStack {
                Label("Launch SlapShift at login", systemImage: "power")
                Spacer()
                Toggle("", isOn: $prefs.launchAtLogin)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }

    private var modesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Modes").font(.title2.weight(.semibold))

            ForEach(modeStore.modes.sorted(by: { $0.slapCount < $1.slapCount })) { mode in
                ModeEditorView(modeID: mode.id)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Modes save automatically. Stored at:")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("~/Library/Application Support/SlapShift/modes.json")
                .font(.caption2.monospaced())
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}
