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
        // Match OnboardingWindow: cream paper, transparent titlebar, single-sheet feel.
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.backgroundColor = NSColor(red: 0.937, green: 0.914, blue: 0.827, alpha: 1)
        win.setContentSize(NSSize(width: 560, height: 600))
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

    private let buyURL = URL(string: "https://slapshift.app/api/checkout")!

    var body: some View {
        ZStack {
            Brand.cream.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                // Header — same serif treatment as the website hero.
                VStack(alignment: .leading, spacing: 8) {
                    (Text("Unlock ").foregroundColor(Brand.ink)
                     + Text("SlapShift").italic().foregroundColor(Brand.accent)
                     + Text(".").foregroundColor(Brand.ink))
                        .font(.slapDisplay(size: 30))
                    Text("One-time purchase.")
                        .font(.slapBody(size: 12))
                        .foregroundStyle(Brand.mute)
                }

                Rectangle().fill(Brand.rule).frame(height: 1)

                // Pitch
                VStack(alignment: .leading, spacing: 10) {
                    pitchRow("Slap to switch your whole workspace")
                    pitchRow("Three modes out of the box, fully editable")
                    pitchRow("Apple Silicon only — runs on your existing Mac")
                }

                // Buy button — inky pill, matches the website "DOWNLOAD FOR MACOS" CTA.
                Button {
                    NSWorkspace.shared.open(buyURL)
                } label: {
                    HStack {
                        Text("Buy a license")
                        Spacer()
                        Text("$9.99")
                    }
                }
                .buttonStyle(InkButtonStyle(fullWidth: true))
                .keyboardShortcut(.defaultAction)

                Rectangle().fill(Brand.rule).frame(height: 1)

                // Key entry
                VStack(alignment: .leading, spacing: 10) {
                    Text("Already have a key?")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(Brand.ink)
                    // macOS 13's native TextField placeholder paints a near-white
                    // color we can't override, so it disappears on cream. Same
                    // ZStack overlay trick OnboardingView uses to keep the
                    // SLAP-XXXX hint visible.
                    ZStack(alignment: .leading) {
                        if key.isEmpty {
                            Text("SLAP-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX")
                                .font(.slapBody(size: 12))
                                .foregroundStyle(Brand.ink.opacity(0.42))
                                .padding(.horizontal, 12)
                                .allowsHitTesting(false)
                        }
                        TextField("", text: $key)
                            .textFieldStyle(.plain)
                            .font(.slapBody(size: 12))
                            .foregroundStyle(Brand.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .disableAutocorrection(true)
                            .disabled(submitting)
                            .onSubmit {
                                if !key.trimmingCharacters(in: .whitespaces).isEmpty && !submitting {
                                    Task { await activate() }
                                }
                            }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Brand.paper)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Brand.rule, lineWidth: 1)
                    )
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.slapBody(size: 11))
                            .foregroundStyle(Brand.accent)
                    }
                    if succeeded {
                        Text("✓ License activated. You can close this window.")
                            .font(.slapBody(size: 11))
                            .foregroundStyle(Brand.hill)
                    }
                    HStack {
                        Button(submitting ? "Activating…" : "Activate") {
                            Task { await activate() }
                        }
                        .buttonStyle(OutlineButtonStyle())
                        .disabled(submitting || key.trimmingCharacters(in: .whitespaces).isEmpty)
                        Spacer()
                        Button(succeeded ? "Done" : "Maybe later") {
                            onDismiss()
                        }
                        .buttonStyle(OutlineButtonStyle())
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 36)
            .padding(.top, 36)
            .padding(.bottom, 28)
        }
        .frame(width: 560, height: 600, alignment: .topLeading)
        .onAppear {
            if let initial = initialKey, !initial.isEmpty {
                key = initial
                Task { await activate() }
            }
        }
    }

    private func pitchRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .font(.slapBody(size: 13))
                .foregroundStyle(Brand.accent)
            Text(text)
                .font(.slapBody(size: 13))
                .foregroundStyle(Brand.ink)
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
