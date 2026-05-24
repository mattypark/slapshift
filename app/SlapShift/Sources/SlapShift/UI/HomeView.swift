// HomeView — Willow-inspired dashboard, tuned for SlapShift's brand.
//
// Layout:
//   ┌── sidebar (240w) ─────────┬── main content ─────────────────────┐
//   │ ⚡ SlapShift               │ Hi, matthew.                        │
//   │                           │ Slap your MacBook to switch modes.  │
//   │ ▸ Home                    │                                     │
//   │   Customization           │ ┌ Slaps ┐  ┌ Time saved ┐           │
//   │                           │ │  127  │  │   6 min    │           │
//   │ COMING SOON               │ └───────┘  └────────────┘           │
//   │   Focus  (soon)           │ ┌ Day str┐ ┌ Avg/day ────┐          │
//   │   Music  (soon)           │ │ 4 days │ │   18        │          │
//   │                           │ └────────┘ └─────────────┘          │
//   │                           │                                     │
//   │                           │ Your modes                          │
//   │ ◯ matthew         ⚙       │ [Coding]  [Apply]  [Wind Down]      │
//   └───────────────────────────┴─────────────────────────────────────┘
//
// Sidebar nav semantics:
//   Home          — selected; this view
//   Customization — opens the existing Settings window (mode editor lives there)
//   Focus / Music — "coming soon" placeholders; disabled with a "soon" pill
//
// The live g-meter previously lived here too. It moved to Settings exclusively
// per user direction — the home is meant to read calm and finished, not show
// engineering plumbing.

import AppKit
import SwiftUI

struct HomeView: View {

    @ObservedObject var modeStore: ModeStore
    @ObservedObject var motionMonitor: MotionMonitor
    @ObservedObject var prefs: AppPreferences
    @ObservedObject var stats: SlapStats
    var onOpenSettings: () -> Void
    var onSignOut: () -> Void

    @State private var selectedSection: Section = .home
    @State private var profileMenuOpen: Bool = false
    @State private var shareCopied: Bool = false

    /// The link copied to the clipboard from "Share SlapShift". This is the
    /// public landing page — the buy button lives there.
    private let shareURL = "https://slapshift.app"

    enum Section: Hashable {
        case home
        case customization
        case focus     // future
        case music     // future
    }

    private var firstName: String {
        let stored = UserDefaults.standard.string(forKey: "onboarding.name") ?? ""
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "friend" }
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }

    private var fullName: String {
        let stored = UserDefaults.standard.string(forKey: "onboarding.name") ?? ""
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Friend" : trimmed
    }

    private var initials: String {
        let parts = fullName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    var body: some View {
        // bottomLeading alignment anchors the profile popover to the
        // bottom-left corner of the window, then explicit padding pushes
        // it up next to the profile chip. Rendering the popover at the
        // body level (above the scrim) is what makes its buttons actually
        // clickable — when it lived inside the sidebar VStack the scrim
        // sat above it in z-order and ate every tap. "Open Settings"
        // looked dead because of that, not because the handler was wrong.
        ZStack(alignment: .bottomLeading) {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 240)
                    // Brand.cream (#ece5d1) is tuned to match slapshiftlogo.png's
                    // backing color exactly, so the logo's tile fuses with the
                    // sidebar surface. creamDeeper looked off against the PNG.
                    .background(Brand.cream)

                Divider()
                    .overlay(Brand.rule.opacity(0.4))

                mainContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Brand.cream)
            }

            if profileMenuOpen {
                // Scrim — invisible click-catcher that dismisses the popover
                // on outside taps. Declared BEFORE the popover so the popover
                // renders on top and its buttons receive hits first.
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { profileMenuOpen = false }

                // Popover lives at body level (not inside the sidebar) so it
                // can render above the scrim. Padding anchors it next to the
                // profile chip: 14pt from the left edge (matches sidebar
                // horizontal padding) and ~72pt up from the bottom (chip
                // height + chip's bottom padding + small gap).
                profilePopover
                    .padding(.leading, 14)
                    .padding(.bottom, 72)
                    .transition(.opacity.combined(with: .offset(y: 4)))
            }
        }
        .animation(.easeOut(duration: 0.12), value: profileMenuOpen)
        .frame(minWidth: 820, minHeight: 580)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                // No wordmark — the PNG carries the SlapShift type. 72pt
                // gives the mark real presence in the corner without
                // crowding the Home / Customization rows below (header has
                // 10pt bottom padding before the first row starts).
                BrandLogo(height: 72)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 2) {
                SidebarRow(
                    icon: "house",
                    title: "Home",
                    isSelected: selectedSection == .home,
                    isComingSoon: false
                ) {
                    selectedSection = .home
                }
                SidebarRow(
                    icon: "slider.horizontal.3",
                    title: "Customization",
                    isSelected: selectedSection == .customization,
                    isComingSoon: false
                ) {
                    // Customization == the existing Settings window. Reset
                    // sidebar selection back to Home after a beat so the
                    // user doesn't get stranded on a non-rendering tab.
                    onOpenSettings()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedSection = .home
                    }
                }
            }
            .padding(.horizontal, 12)

            sectionHeader("Coming Soon")
                .padding(.top, 28)

            VStack(alignment: .leading, spacing: 2) {
                SidebarRow(
                    icon: "moon.fill",
                    title: "Focus",
                    isSelected: false,
                    isComingSoon: true
                ) { /* disabled */ }
                SidebarRow(
                    icon: "music.note",
                    title: "Music",
                    isSelected: false,
                    isComingSoon: true
                ) { /* disabled */ }
            }
            .padding(.horizontal, 12)

            Spacer()

            profileFooter
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.slapMeta(size: 10))
            .tracking(0.2)
            .foregroundStyle(Brand.whisper)
            .padding(.horizontal, 22)
            .padding(.bottom, 6)
    }

    private var profileFooter: some View {
        // Just the chip — the popover renders at body level (see body var)
        // so it can sit above the dismiss scrim and stay clickable. The chip
        // stays anchored to the sidebar bottom via the Spacer above it.
        profileChip
    }

    private var profileChip: some View {
        // Entire chip is one tap target — Willow-style. Clicking anywhere on
        // the row opens the popover above with account actions.
        Button {
            profileMenuOpen.toggle()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Brand.accent.opacity(0.15))
                    Text(initials.isEmpty ? "?" : initials)
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundStyle(Brand.accent)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 1) {
                    Text(fullName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Brand.ink)
                        .lineLimit(1)
                    Text("Licensed")
                        .font(.slapMeta(size: 10))
                        .foregroundStyle(Brand.mute)
                }

                Spacer(minLength: 4)

                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(Brand.mute)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Brand.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Brand.rule.opacity(0.4), lineWidth: 1)
        )
    }

    /// Popover content shown when the profile chip is tapped. Three actions:
    ///   • Open Settings… — same as the old gear menu
    ///   • Share SlapShift — copies the landing URL to the clipboard so the
    ///     user can paste it into iMessage / Twitter / wherever. Inline
    ///     "Copied" confirmation; no extra share sheet (NSSharingService is
    ///     heavy and breaks the calm one-popover feel).
    ///   • Sign Out… — same as the old gear menu.
    private var profilePopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            popoverRow(systemImage: "slider.horizontal.3", label: "Open Settings…") {
                profileMenuOpen = false
                onOpenSettings()
            }
            popoverRow(
                systemImage: shareCopied ? "checkmark" : "square.and.arrow.up",
                label: shareCopied ? "Copied to clipboard" : "Share SlapShift"
            ) {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(shareURL, forType: .string)
                shareCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    shareCopied = false
                    profileMenuOpen = false
                }
            }
            // Hairline rule between primary actions and Sign Out — same Brand.rule
            // as the rest of the app for visual continuity.
            Rectangle()
                .fill(Brand.rule.opacity(0.5))
                .frame(height: 1)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            popoverRow(systemImage: "arrow.right.square", label: "Sign Out…", destructive: true) {
                profileMenuOpen = false
                onSignOut()
            }
        }
        .padding(.vertical, 6)
        .frame(width: 212)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Brand.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Brand.rule.opacity(0.55), lineWidth: 1)
        )
        // Soft drop shadow lifts the card off the sidebar so it reads as
        // floating, not glued. Matches Willow's soft shadow density.
        .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 6)
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
    }

    @ViewBuilder
    private func popoverRow(
        systemImage: String,
        label: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        PopoverRow(
            systemImage: systemImage,
            label: label,
            destructive: destructive,
            action: action
        )
    }

    // MARK: - Main content

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                greetingBlock
                statsGrid
                modesBlock
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            (Text("Hi, ").foregroundColor(Brand.ink)
             + Text(firstName).italic().foregroundColor(Brand.accent)
             + Text(".").foregroundColor(Brand.ink))
                .font(.slapDisplay(size: 36))
                .fixedSize(horizontal: false, vertical: true)

            Text("Slap your MacBook to switch modes.")
                .font(.slapBody(size: 13))
                .foregroundStyle(Brand.mute)
        }
    }

    private var statsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
        ]
        return LazyVGrid(columns: columns, spacing: 14) {
            StatCard(
                label: "Slaps",
                value: "\(stats.totalSlaps)",
                unit: stats.totalSlaps == 1 ? "slap" : "slaps",
                icon: "hand.tap.fill"
            )
            StatCard(
                label: "Time saved",
                value: stats.timeSavedDisplay.split(separator: " ").first.map(String.init) ?? "0",
                unit: stats.timeSavedDisplay.split(separator: " ").dropFirst().joined(separator: " "),
                icon: "clock"
            )
            StatCard(
                label: "Day streak",
                value: "\(stats.dayStreak)",
                unit: stats.dayStreak == 1 ? "day" : "days",
                icon: "flame"
            )
            StatCard(
                label: "Avg / day",
                value: "\(stats.avgSlapsPerDay)",
                unit: "slaps",
                icon: "chart.bar"
            )
        }
    }

    private var modesBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your modes")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(Brand.ink)
                Spacer()
                Button("Edit in Settings", action: onOpenSettings)
                    .buttonStyle(.plain)
                    .font(.slapMeta(size: 11))
                    .foregroundStyle(Brand.accent)
            }
            HStack(spacing: 12) {
                ForEach(1...3, id: \.self) { count in
                    ModeCard(
                        slapCount: count,
                        mode: modeStore.mode(forSlapCount: count),
                        onEdit: onOpenSettings
                    )
                }
            }
        }
    }
}

// MARK: - Sidebar row

private struct SidebarRow: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let isComingSoon: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { if !isComingSoon { action() } }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(foregroundColor)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(foregroundColor)
                Spacer()
                if isComingSoon {
                    Text("soon")
                        .font(.slapMeta(size: 9))
                        .tracking(0.15)
                        .foregroundStyle(Brand.whisper)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Brand.paper)
                        )
                        .overlay(
                            Capsule().stroke(Brand.rule.opacity(0.5), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Brand.paper : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Brand.rule.opacity(0.6) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isComingSoon)
    }

    private var foregroundColor: Color {
        if isComingSoon { return Brand.whisper }
        return isSelected ? Brand.ink : Brand.mute
    }
}

// MARK: - Stat card

private struct StatCard: View {
    let label: String
    let value: String
    let unit: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label)
                    .font(.slapMeta(size: 11))
                    .tracking(0.15)
                    .textCase(.uppercase)
                    .foregroundStyle(Brand.mute)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Brand.whisper)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(Brand.ink)
                Text(unit)
                    .font(.slapBody(size: 12))
                    .foregroundStyle(Brand.mute)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Brand.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Brand.rule.opacity(0.5), lineWidth: 1)
        )
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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(slapLabel.uppercased())
                        .font(.slapMeta(size: 10))
                        .tracking(0.2)
                        .foregroundStyle(Brand.mute)
                    Spacer()
                    Image(systemName: mode?.symbol ?? "questionmark.square.dashed")
                        .font(.system(size: 14))
                        .foregroundStyle(Brand.accent)
                }
                Text(mode?.name ?? "Unbound")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Brand.ink)
                    .lineLimit(1)
                Text(summary)
                    .font(.slapBody(size: 11))
                    .foregroundStyle(Brand.mute)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
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

/// One row in the in-app profile popover. Pulled out so we can carry per-row
/// hover state without bloating HomeView. Hover highlight uses Brand.cream
/// (a touch warmer than Brand.paper) so the active row reads clearly without
/// being loud — matches Willow's quiet hover treatment.
private struct PopoverRow: View {
    let systemImage: String
    let label: String
    let destructive: Bool
    let action: () -> Void

    @State private var hovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(destructive ? Brand.accent : Brand.ink)
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(destructive ? Brand.accent : Brand.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hovered ? Brand.cream : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .onHover { hovered = $0 }
    }
}
