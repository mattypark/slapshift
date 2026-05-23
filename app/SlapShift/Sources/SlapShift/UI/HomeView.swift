// HomeView — Willow-style post-purchase home dashboard.
//
// What lives here:
//   - Greeting header anchored top-left with the SlapShift logo
//   - Big "Hi, $name" title + tagline so the buyer sees their name
//   - Three mode cards (1 / 2 / 3 slaps) showing what fires on each gesture
//   - Live sensor row: armed/disarmed indicator + last-slap meter
//   - Footer with Settings / Test Slap / Quit
//
// Why this exists separately from SettingsView:
//   SettingsView is the deep-config surface (mode editor, sliders, app picker).
//   HomeView is the at-a-glance status board the user opens after activation
//   or from the menu bar's "Show Home" — read-only summary, one click into
//   Settings if they want to actually edit anything. Splitting the two keeps
//   the daily-use surface uncluttered while Settings stays the power-user
//   panel.
//
// The buyer's name is read from UserDefaults (persisted by
// AppDelegate.persistOnboardingProfile on onboarding finish). Greeting falls
// back to "friend" if no name was recorded.

import AppKit
import SwiftUI

struct HomeView: View {

    @ObservedObject var modeStore: ModeStore
    @ObservedObject var motionMonitor: MotionMonitor
    @ObservedObject var prefs: AppPreferences
    var onOpenSettings: () -> Void

    private var firstName: String {
        let stored = UserDefaults.standard.string(forKey: "onboarding.name") ?? ""
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "friend" }
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }

    /// Convert the live accelerometer magnitude (1.0 = resting gravity, peaks
    /// at the slap threshold ~1.3-1.5) into a 0...1 bar fill. We anchor 0 to
    /// 1.0g (resting) so the bar sits empty when nothing's happening, and
    /// 1.0 to the configured slap threshold so a real slap fills the bar
    /// completely.
    private var meterFill: Double {
        let baseline = 1.0
        let ceiling = max(prefs.slapThresholdG, baseline + 0.05)
        let raw = (motionMonitor.liveMagnitude - baseline) / (ceiling - baseline)
        return min(max(raw, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Brand.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 32)
                    .padding(.top, 22)

                Spacer(minLength: 0)

                content
                    .padding(.horizontal, 48)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                footer
                    .padding(.horizontal, 32)
                    .padding(.bottom, 22)
            }
        }
        .frame(minWidth: 640, minHeight: 520)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            BrandLogo(height: 88)
            Spacer()
            // Right-side cluster: small "armed" status pill so the user can
            // confirm at a glance that slap detection is live.
            HStack(spacing: 6) {
                Circle()
                    .fill(Brand.hill)
                    .frame(width: 7, height: 7)
                Text("Armed")
                    .font(.slapMeta(size: 10))
                    .tracking(0.15)
                    .textCase(.uppercase)
                    .foregroundStyle(Brand.mute)
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 26) {
            VStack(spacing: 8) {
                (Text("Hi, ").foregroundColor(Brand.ink)
                 + Text(firstName).italic().foregroundColor(Brand.accent)
                 + Text(".").foregroundColor(Brand.ink))
                    .font(.slapDisplay(size: 44))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Slap your MacBook to switch modes.")
                    .font(.slapBody(size: 13))
                    .foregroundStyle(Brand.mute)
            }

            modeCardsRow

            meterRow
        }
        .frame(maxWidth: 720)
    }

    private var modeCardsRow: some View {
        HStack(spacing: 14) {
            ForEach(1...3, id: \.self) { count in
                ModeCard(
                    slapCount: count,
                    mode: modeStore.mode(forSlapCount: count),
                    onEdit: onOpenSettings
                )
            }
        }
    }

    private var meterRow: some View {
        // Live g-force bar so the user can confirm the sensor is reading
        // their taps. Same visual primitive as the Settings live meter,
        // simplified for the home dashboard (no calibration controls).
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Live sensor")
                    .font(.slapMeta(size: 10))
                    .tracking(0.18)
                    .textCase(.uppercase)
                    .foregroundStyle(Brand.mute)
                Spacer()
                Text(String(format: "%.2fg", motionMonitor.liveMagnitude))
                    .font(.slapMeta(size: 10))
                    .foregroundStyle(Brand.whisper)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Brand.paper)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(meterFill > 0.85 ? Brand.accent : Brand.hill)
                        .frame(width: geo.size.width * CGFloat(meterFill))
                        .animation(.easeOut(duration: 0.08), value: meterFill)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Brand.rule.opacity(0.5), lineWidth: 1)
                )
            }
            .frame(height: 8)
        }
        .frame(maxWidth: 540)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Settings") { onOpenSettings() }
                .buttonStyle(OutlineButtonStyle())

            Spacer()

            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.slapMeta(size: 10))
                .foregroundStyle(Brand.whisper)
        }
    }
}

// MARK: - Mode card

/// Compact card showing what a slap-count fires. Tapping it opens Settings
/// (where the mode editor lives). Read-only on the home — daily-use surface,
/// not the place to mutate config.
private struct ModeCard: View {
    let slapCount: Int
    let mode: Mode?
    let onEdit: () -> Void

    private var slapLabel: String {
        "\(slapCount) slap\(slapCount > 1 ? "s" : "")"
    }

    private var summary: String {
        guard let mode = mode else { return "Not configured" }
        let parts = [
            mode.appsToOpen.count > 0 ? "\(mode.appsToOpen.count) open" : nil,
            mode.appsToQuit.count > 0 ? "\(mode.appsToQuit.count) quit" : nil,
            mode.urlsToOpen.count > 0 ? "\(mode.urlsToOpen.count) URL\(mode.urlsToOpen.count > 1 ? "s" : "")" : nil,
        ].compactMap { $0 }
        return parts.isEmpty ? "Empty mode" : parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(slapLabel.uppercased())
                        .font(.slapMeta(size: 10))
                        .tracking(0.2)
                        .foregroundStyle(Brand.mute)
                    Spacer()
                    Image(systemName: mode?.symbol ?? "questionmark.square.dashed")
                        .font(.system(size: 16))
                        .foregroundStyle(Brand.accent)
                }
                Text(mode?.name ?? "Unbound")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(Brand.ink)
                    .lineLimit(1)
                Text(summary)
                    .font(.slapBody(size: 11))
                    .foregroundStyle(Brand.mute)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Brand.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Brand.rule.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
