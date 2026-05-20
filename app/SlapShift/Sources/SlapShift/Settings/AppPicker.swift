// AppPicker — modal sheet that lets the user pick apps from /Applications.
//
// Multi-select, searchable, icon + name display. Used twice in the mode editor:
// once for "apps to open" and once for "apps to quit."

import SwiftUI

struct AppPickerView: View {

    let title: String
    let preselected: Set<String>           // bundle IDs already in the mode
    let onConfirm: ([String]) -> Void      // returns the new full set of bundle IDs
    let onCancel: () -> Void

    @State private var apps: [InstalledApp] = []
    @State private var selected: Set<String> = []
    @State private var searchQuery: String = ""
    @State private var isLoading: Bool = true

    var filtered: [InstalledApp] {
        guard !searchQuery.isEmpty else { return apps }
        let q = searchQuery.lowercased()
        return apps.filter { $0.name.lowercased().contains(q) || $0.bundleID.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text("\(selected.count) selected").foregroundColor(.secondary).font(.caption)
            }
            .padding()

            Divider()

            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search apps...", text: $searchQuery)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if isLoading {
                ProgressView("Scanning installed apps...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { app in
                            AppRow(app: app, isSelected: selected.contains(app.bundleID))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selected.contains(app.bundleID) {
                                        selected.remove(app.bundleID)
                                    } else {
                                        selected.insert(app.bundleID)
                                    }
                                }
                            Divider()
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Confirm (\(selected.count))") {
                    onConfirm(Array(selected))
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 480, height: 540)
        .onAppear {
            selected = preselected
            DispatchQueue.global(qos: .userInitiated).async {
                let result = InstalledApps.list()
                DispatchQueue.main.async {
                    self.apps = result
                    self.isLoading = false
                }
            }
        }
    }
}

private struct AppRow: View {
    let app: InstalledApp
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).font(.body)
                Text(app.bundleID).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}
