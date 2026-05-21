// LicenseSheet — paywall + key entry. NSWindowController hosting a SwiftUI view.
//
// Shown in two situations:
//   1) Paywall: fires after the user's first real slap if they aren't licensed.
//      Sells the product first, key entry second.
//   2) Manual entry: from Settings → License, or the slapshift:// URL handler.
//
// SwiftUI view stays dumb — `LicenseManager` owns all state and side effects.

import AppKit
import SwiftUI

final class LicenseSheet {

    private var window: NSWindow?
    private let manager: LicenseManager
    private let initialKey: String?
    private let onClose: () -> Void

    init(manager: LicenseManager, initialKey: String? = nil, onClose: @escaping () -> Void = {}) {
        self.manager = manager
        self.initialKey = initialKey
        self.onClose = onClose
    }

    func show() {
        if let existing = window {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let view = LicenseSheetView(
            manager: manager,
            initialKey: initialKey,
            onDismiss: { [weak self] in self?.close() }
        )
        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Unlock SlapShift"
        win.styleMask = [.titled, .closable]
        win.setContentSize(NSSize(width: 520, height: 540))
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = WindowDelegate.shared

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        window = win
    }

    func close() {
        window?.close()
        window = nil
        onClose()
    }

    private final class WindowDelegate: NSObject, NSWindowDelegate {
        static let shared = WindowDelegate()
        func windowWillClose(_ notification: Notification) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

// MARK: - SwiftUI body

private struct LicenseSheetView: View {
    @ObservedObject var manager: LicenseManager
    let initialKey: String?
    let onDismiss: () -> Void

    @State private var key: String = ""
    @State private var submitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var succeeded: Bool = false

    private let buyURL = URL(string: "https://slapshift.app/#pricing")!

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Unlock SlapShift")
                    .font(.system(size: 26, weight: .semibold))
                Text("One-time purchase. All sales final.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Pitch
            VStack(alignment: .leading, spacing: 8) {
                pitchRow("Slap to switch your whole workspace")
                pitchRow("Three modes out of the box, fully editable")
                pitchRow("Apple Silicon only — runs on your existing Mac")
            }

            // Buy button
            Button {
                NSWorkspace.shared.open(buyURL)
            } label: {
                HStack {
                    Text("Buy a license")
                    Spacer()
                    Text("$9.99")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            Divider()

            // Key entry
            VStack(alignment: .leading, spacing: 8) {
                Text("Already have a key?")
                    .font(.system(size: 13, weight: .medium))
                TextField("SLAP-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX", text: $key)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .disableAutocorrection(true)
                    .disabled(submitting)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                if succeeded {
                    Text("✓ License activated. You can close this window.")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                }
                HStack {
                    Button(submitting ? "Activating…" : "Activate") {
                        Task { await activate() }
                    }
                    .disabled(submitting || key.trimmingCharacters(in: .whitespaces).isEmpty)
                    Spacer()
                    Button(succeeded ? "Done" : "Maybe later") {
                        onDismiss()
                    }
                }
            }

            Spacer()
        }
        .padding(28)
        .frame(width: 520, height: 540, alignment: .topLeading)
        .onAppear {
            if let initial = initialKey, !initial.isEmpty {
                key = initial
                Task { await activate() }
            }
        }
    }

    private func pitchRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").foregroundStyle(.secondary)
            Text(text).font(.system(size: 13))
        }
    }

    private func activate() async {
        errorMessage = nil
        succeeded = false
        submitting = true
        defer { submitting = false }
        let result = await manager.tryActivate(key: key)
        switch result {
        case .success:
            succeeded = true
        case .failure(let err):
            errorMessage = err.userMessage
        }
    }
}
