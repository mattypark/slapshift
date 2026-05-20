// ModeEditorView — edit one Mode (apps, URLs, focus, etc.).
//
// Used as a card inside SettingsView. Holds local @State while editing, commits to ModeStore
// on each change so the JSON file stays in sync with the UI.

import SwiftUI

struct ModeEditorView: View {

    @EnvironmentObject var modeStore: ModeStore
    let modeID: UUID

    @State private var showingOpenPicker = false
    @State private var showingQuitPicker = false
    @State private var newURL: String = ""

    /// Common macOS Focus modes. User can type any custom Focus name too.
    private let focusSuggestions = ["Do Not Disturb", "Work", "Personal", "Sleep", "Reading", "Fitness", "Gaming", "Driving"]

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
            VStack(alignment: .leading, spacing: 16) {
                header(mode)
                Divider()
                appsSection(mode)
                Divider()
                urlsSection(mode)
                Divider()
                focusSection(mode)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
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

    private func header(_ mode: Mode) -> some View {
        HStack(spacing: 12) {
            Image(systemName: mode.symbol)
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                TextField("Mode name", text: Binding(
                    get: { mode.name },
                    set: { newName in commit { $0.name = newName } }
                ))
                .textFieldStyle(.plain)
                .font(.title2.weight(.semibold))

                Text("\(mode.slapCount) slap\(mode.slapCount > 1 ? "s" : "")")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }

            Spacer()

            Toggle("Enabled", isOn: Binding(
                get: { mode.enabled },
                set: { newVal in commit { $0.enabled = newVal } }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    private func appsSection(_ mode: Mode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Apps to open", systemImage: "app.badge.checkmark")
                    .font(.headline)
                Spacer()
                Button("Edit") { showingOpenPicker = true }
            }
            appsRow(mode.appsToOpen, emptyLabel: "No apps configured")

            HStack {
                Label("Apps to quit", systemImage: "xmark.app")
                    .font(.headline)
                Spacer()
                Button("Edit") { showingQuitPicker = true }
            }
            appsRow(mode.appsToQuit, emptyLabel: "No apps to quit")
        }
    }

    private func appsRow(_ bundleIDs: [String], emptyLabel: String) -> some View {
        Group {
            if bundleIDs.isEmpty {
                Text(emptyLabel)
                    .foregroundColor(.secondary)
                    .font(.caption)
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
            }
            Text(resolved?.name ?? bundleID)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.12))
        .cornerRadius(6)
    }

    private func urlsSection(_ mode: Mode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("URLs to open (in your default browser)", systemImage: "link")
                .font(.headline)

            ForEach(mode.urlsToOpen, id: \.self) { url in
                HStack {
                    Image(systemName: "globe").foregroundColor(.secondary)
                    Text(url).font(.caption.monospaced()).lineLimit(1)
                    Spacer()
                    Button(action: {
                        commit { $0.urlsToOpen.removeAll { $0 == url } }
                    }) {
                        Image(systemName: "minus.circle.fill").foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("https://example.com", text: $newURL)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addURL)
                Button("Add", action: addURL)
                    .disabled(newURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addURL() {
        let trimmed = newURL.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let normalized = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        commit { $0.urlsToOpen.append(normalized) }
        newURL = ""
    }

    private func focusSection(_ mode: Mode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Focus mode to enter (optional)", systemImage: "moon.circle")
                .font(.headline)

            HStack {
                TextField("e.g. Do Not Disturb", text: Binding(
                    get: { mode.focusModeName ?? "" },
                    set: { newVal in
                        commit { $0.focusModeName = newVal.isEmpty ? nil : newVal }
                    }
                ))
                .textFieldStyle(.roundedBorder)

                Menu("Suggestions") {
                    Button("(none)") {
                        commit { $0.focusModeName = nil }
                    }
                    ForEach(focusSuggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            commit { $0.focusModeName = suggestion }
                        }
                    }
                }
                .frame(width: 130)
            }

            Text("Requires SlapShift's first-run Shortcut installer (Weekend 3 follow-up). Without it, Focus changes silently no-op.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
