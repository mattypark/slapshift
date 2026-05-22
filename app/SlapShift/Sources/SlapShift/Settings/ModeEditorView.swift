// ModeEditorView — edit one Mode (apps, URLs).
//
// Used as a card inside SettingsView. Holds local @State while editing, commits to ModeStore
// on each change so the JSON file stays in sync with the UI.
//
// Brand match: cream paper surface, ink text, Newsreader serif headlines, mono body,
// red accent — same vocabulary as the website + onboarding window.
//
// NOTE: Focus mode editing was removed in v1.0. See Modes/Mode.swift for rationale.

import SwiftUI

struct ModeEditorView: View {

    @EnvironmentObject var modeStore: ModeStore
    let modeID: UUID

    @State private var showingOpenPicker = false
    @State private var showingQuitPicker = false
    @State private var newURL: String = ""

    private var mode: Mode? {
        modeStore.modes.first(where: { $0.id == modeID })
    }

    private func commit(_ block: (inout Mode) -> Void) {
        guard var m = mode else { return }
        block(&m)
        modeStore.update(m)
    }

    var body: some View {
        guard let mode = mode else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 18) {
                header(mode)
                hairline
                appsSection(mode)
                hairline
                urlsSection(mode)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Brand.cream)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Brand.rule.opacity(0.5), lineWidth: 1)
            )
            .sheet(isPresented: $showingOpenPicker) {
                AppPickerView(
                    title: "Apps to open for \(mode.name)",
                    preselected: Set(mode.appsToOpen),
                    onConfirm: { bundleIDs in
                        commit { $0.appsToOpen = bundleIDs }
                        showingOpenPicker = false
                    },
                    onCancel: { showingOpenPicker = false }
                )
            }
            .sheet(isPresented: $showingQuitPicker) {
                AppPickerView(
                    title: "Apps to quit for \(mode.name)",
                    preselected: Set(mode.appsToQuit),
                    onConfirm: { bundleIDs in
                        commit { $0.appsToQuit = bundleIDs }
                        showingQuitPicker = false
                    },
                    onCancel: { showingQuitPicker = false }
                )
            }
        )
    }

    // MARK: - Sections

    private var hairline: some View {
        Rectangle()
            .fill(Brand.rule.opacity(0.4))
            .frame(height: 1)
    }

    private func header(_ mode: Mode) -> some View {
        HStack(spacing: 14) {
            Image(systemName: mode.symbol)
                .font(.system(size: 24))
                .foregroundStyle(Brand.accent)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Brand.paper)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Brand.rule.opacity(0.5), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                TextField("Mode name", text: Binding(
                    get: { mode.name },
                    set: { newName in commit { $0.name = newName } }
                ))
                .textFieldStyle(.plain)
                .font(.slapTitle(size: 20))
                .foregroundStyle(Brand.ink)

                Text("\(mode.slapCount) slap\(mode.slapCount > 1 ? "s" : "")")
                    .font(.slapMeta(size: 11))
                    .foregroundStyle(Brand.mute)
                    .tracking(0.4)
                    .textCase(.uppercase)
            }

            Spacer()

            Toggle("Enabled", isOn: Binding(
                get: { mode.enabled },
                set: { newVal in commit { $0.enabled = newVal } }
            ))
            .toggleStyle(.switch)
            .tint(Brand.accent)
            .labelsHidden()
        }
    }

    private func appsSection(_ mode: Mode) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionLabel("Apps to open", systemImage: "app.badge.checkmark")
                    Spacer()
                    Button("Edit") { showingOpenPicker = true }
                        .buttonStyle(EditPillStyle())
                }
                appsRow(mode.appsToOpen, emptyLabel: "No apps configured")
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionLabel("Apps to quit", systemImage: "xmark.app")
                    Spacer()
                    Button("Edit") { showingQuitPicker = true }
                        .buttonStyle(EditPillStyle())
                }
                appsRow(mode.appsToQuit, emptyLabel: "No apps to quit")
            }
        }
    }

    private func appsRow(_ bundleIDs: [String], emptyLabel: String) -> some View {
        Group {
            if bundleIDs.isEmpty {
                Text(emptyLabel)
                    .font(.slapBody(size: 11))
                    .foregroundStyle(Brand.whisper)
                    .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(bundleIDs, id: \.self) { bundleID in
                            appChip(bundleID: bundleID)
                        }
                    }
                }
            }
        }
    }

    private func appChip(bundleID: String) -> some View {
        let resolved = InstalledApps.resolve(bundleID: bundleID)
        return HStack(spacing: 6) {
            if let icon = resolved?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: "questionmark.app.dashed")
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Brand.mute)
            }
            Text(resolved?.name ?? bundleID)
                .font(.slapBody(size: 11))
                .foregroundStyle(Brand.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Brand.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Brand.rule.opacity(0.5), lineWidth: 1)
        )
    }

    private func urlsSection(_ mode: Mode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("URLs to open (in your default browser)", systemImage: "link")

            ForEach(mode.urlsToOpen, id: \.self) { url in
                HStack(spacing: 8) {
                    Image(systemName: "globe").foregroundStyle(Brand.mute)
                    Text(url)
                        .font(.slapBody(size: 11))
                        .foregroundStyle(Brand.ink)
                        .lineLimit(1)
                    Spacer()
                    Button(action: {
                        commit { $0.urlsToOpen.removeAll { $0 == url } }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(Brand.accent.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 8) {
                TextField("https://example.com", text: $newURL)
                    .textFieldStyle(.plain)
                    .font(.slapBody(size: 12))
                    .foregroundStyle(Brand.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Brand.paper)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Brand.rule.opacity(0.6), lineWidth: 1)
                    )
                    .onSubmit(addURL)
                Button("Add", action: addURL)
                    .buttonStyle(EditPillStyle())
                    .disabled(newURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func sectionLabel(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12))
                .foregroundStyle(Brand.accent)
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(Brand.ink)
        }
    }

    private func addURL() {
        let trimmed = newURL.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let normalized = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        commit { $0.urlsToOpen.append(normalized) }
        newURL = ""
    }
}

// MARK: - Edit pill button

/// Small "Edit" / "Add" pill — outline style, matches the website's secondary buttons.
private struct EditPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.slapMeta(size: 11))
            .tracking(0.06)
            .textCase(.uppercase)
            .foregroundStyle(Brand.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(configuration.isPressed ? Brand.creamDeeper : Brand.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Brand.ink.opacity(0.6), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
