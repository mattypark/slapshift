// OnboardingView — first-run flow.
//
// Step map (left→right):
//   welcome      — centered logo + "Welcome to SlapShift" + Continue
//   signin       — Continue with Google / Continue with Apple
//   name         — "What should we call you?" + email confirmation
//   usage        — multi-select cards: what will you use this for
//   permission   — grant Input Monitoring (motion sensor)
//   shortcuts    — install the 3 bundled Shortcuts
//   howItWorks   — placeholder for the demo video
//   paywall      — $9.99 one-time, in-app. Buy now / Try free
//   testSlap     — slap your Mac to confirm the sensor works → Finish
//
// Theme: matches the slapshift.app website (Brand.cream background, accent
// red, serif headlines, monospace body). See Theme.swift for tokens.
//
// Auth: Phase 1 uses StubAuthService — buttons look real, response is faked.
// Phase 2 replaces with SupabaseAuthService and the same public surface.

import SwiftUI

struct OnboardingView: View {

    @ObservedObject var state: OnboardingState

    var onFinish: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Brand.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 28)
                    .padding(.top, 24)

                Spacer(minLength: 0)

                content
                    .padding(.horizontal, 48)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer(minLength: 0)

                footer
                    .padding(.horizontal, 28)
                    .padding(.bottom, 22)
            }
        }
        .frame(width: 720, height: 640)
    }

    // MARK: - Header (logo + progress dots)

    private var header: some View {
        HStack {
            BrandLogo(height: 28)
            Spacer()
            StepDots(current: state.step.index, total: OnboardingState.Step.allCases.count)
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var content: some View {
        switch state.step {
        case .welcome:     WelcomeStep()
        case .signin:      SignInStep(state: state)
        case .name:        NameStep(state: state)
        case .usage:       UsageStep(state: state)
        case .permission:  PermissionStep(state: state)
        case .shortcuts:   ShortcutsStep(state: state)
        case .howItWorks:  HowItWorksStep()
        case .paywall:     PaywallStep(state: state)
        case .testSlap:    TestSlapStep(state: state)
        }
    }

    // MARK: - Footer (Back + Continue / Finish)

    private var footer: some View {
        HStack(spacing: 12) {
            if state.step != .welcome && state.step != .signin {
                Button("Back") { state.back() }
                    .buttonStyle(OutlineButtonStyle())
                    .keyboardShortcut(.escape)
            }

            Spacer()

            // Steps that have their own primary CTAs (signin uses the SSO buttons,
            // paywall has Buy/Skip) suppress the global Continue button so we
            // don't end up with two competing primary actions on screen.
            if state.step != .signin && state.step != .paywall {
                Button(action: advance) {
                    Text(state.step == .testSlap ? "Finish" : "Continue")
                }
                .buttonStyle(InkButtonStyle())
                .keyboardShortcut(.return)
                .disabled(!state.canAdvance)
                .opacity(state.canAdvance ? 1 : 0.45)
            }
        }
    }

    private func advance() {
        if state.step == .testSlap {
            onFinish()
        } else {
            state.next()
        }
    }
}

// MARK: - Step views

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 18) {
            // Big serif hero — mirrors the website's "Slap your Mac, workflow maxed."
            // Italic accent on the keywords "Mac" and "maxed", matching the landing
            // page hero exactly so the buyer feels continuity from web → app.
            // Text+Text concatenation uses .foregroundColor on the Text operands
            // (works on macOS 13) rather than .foregroundStyle, which on Text+
            // only got the right overload in macOS 14.
            (Text("Slap your ").foregroundColor(Brand.ink)
             + Text("Mac").italic().foregroundColor(Brand.accent)
             + Text(",\nworkflow ").foregroundColor(Brand.ink)
             + Text("maxed").italic().foregroundColor(Brand.accent)
             + Text(".").foregroundColor(Brand.ink))
                .font(.slapDisplay(size: 40))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("One gesture rewrites your whole workspace.\nLet's set yours up.")
                .font(.slapBody(size: 13))
                .foregroundStyle(Brand.mute)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: 520)
    }
}

private struct SignInStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Sign in to continue")
                    .font(.slapTitle(size: 26))
                    .foregroundStyle(Brand.ink)
                Text("We use this so your license follows you across Macs.")
                    .font(.slapBody(size: 12))
                    .foregroundStyle(Brand.mute)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button(action: { Task { await state.signIn(with: .google) } }) {
                    HStack(spacing: 12) {
                        GoogleLogo(size: 18)
                        Text("Continue with Google")
                        Spacer()
                    }
                }
                .buttonStyle(SSOButtonStyle())
                .disabled(state.signingIn)

                Button(action: { Task { await state.signIn(with: .apple) } }) {
                    HStack(spacing: 12) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 16))
                            .foregroundStyle(Brand.ink)
                        Text("Continue with Apple")
                        Spacer()
                    }
                }
                .buttonStyle(SSOButtonStyle())
                .disabled(state.signingIn)
            }
            .frame(maxWidth: 360)

            if state.signingIn {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Connecting to \(state.pendingProvider?.displayName ?? "")…")
                        .font(.slapMeta(size: 11))
                        .foregroundStyle(Brand.mute)
                }
                .padding(.top, 4)
            } else if let err = state.signInError {
                Text(err)
                    .font(.slapMeta(size: 11))
                    .foregroundStyle(Brand.accent)
            }

            Button("← Back to welcome") { state.back() }
                .buttonStyle(.plain)
                .font(.slapMeta(size: 11))
                .foregroundStyle(Brand.mute)
                .padding(.top, 8)
        }
        .frame(maxWidth: 420)
    }
}

private struct NameStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text("What should we call you?")
                    .font(.slapTitle(size: 24))
                    .foregroundStyle(Brand.ink)
                Text("And confirm the email where your license should go.")
                    .font(.slapBody(size: 12))
                    .foregroundStyle(Brand.mute)
            }

            VStack(spacing: 14) {
                LabeledField(label: "Name", text: $state.name, placeholder: "Matthew Park")
                LabeledField(label: "Email", text: $state.email, placeholder: "you@example.com")
                    .disableAutocorrection(true)
                    .textCase(.lowercase)
            }
            .frame(maxWidth: 380)
        }
        .frame(maxWidth: 480)
    }
}

private struct UsageStep: View {
    @ObservedObject var state: OnboardingState

    private let options: [(id: String, icon: String, title: String, sub: String)] = [
        ("coding",   "terminal.fill",        "Coding",            "Boot a dev workspace in one slap."),
        ("school",   "graduationcap.fill",   "School / applying", "Open your tabs and a focus mode."),
        ("writing",  "pencil.and.scribble",  "Writing",           "Quit distractions, open the doc."),
        ("designing","paintpalette.fill",    "Designing",         "Figma + reference tabs + DND."),
        ("research", "books.vertical.fill",  "Research",          "Notes + sources + zen mode."),
        ("fun",      "sparkles",             "Just curious",      "I want to slap my laptop."),
    ]

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("What'll you use SlapShift for?")
                    .font(.slapTitle(size: 24))
                    .foregroundStyle(Brand.ink)
                Text("Pick as many as you want — we'll preload modes that fit.")
                    .font(.slapBody(size: 12))
                    .foregroundStyle(Brand.mute)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                ForEach(options, id: \.id) { opt in
                    SelectableCard(
                        icon: opt.icon,
                        title: opt.title,
                        subtitle: opt.sub,
                        isSelected: state.usage.contains(opt.id),
                        action: { state.toggleUsage(opt.id) }
                    )
                }
            }
            .frame(maxWidth: 520)
        }
    }
}

private struct PermissionStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield")
                .font(.system(size: 44))
                .foregroundStyle(Brand.accent)
            Text("Grant Input Monitoring")
                .font(.slapTitle(size: 24))
                .foregroundStyle(Brand.ink)
            Text("SlapShift reads the motion sensor in your MacBook to detect a slap. macOS treats motion as input, so it needs Input Monitoring permission.")
                .font(.slapBody(size: 13))
                .foregroundStyle(Brand.mute)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 480)

            Button("Open System Settings") { state.openInputMonitoringSettings() }
                .buttonStyle(OutlineButtonStyle())
                .padding(.top, 6)

            statusRow(done: state.permissionGranted,
                      doneText: "Permission granted",
                      waitText: "Waiting for permission…")
        }
    }
}

private struct ShortcutsStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 44))
                .foregroundStyle(Brand.accent)
            Text("Install your starter shortcuts")
                .font(.slapTitle(size: 24))
                .foregroundStyle(Brand.ink)
            Text("Three Shortcuts — Coding, Apply, Wind Down — handle quitting apps and entering Focus. We'll add them to your library.")
                .font(.slapBody(size: 13))
                .foregroundStyle(Brand.mute)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 480)

            Button("Install Shortcuts") { state.installDefaultShortcuts() }
                .buttonStyle(OutlineButtonStyle())
                .disabled(state.shortcutsInstalled)
                .opacity(state.shortcutsInstalled ? 0.5 : 1)
                .padding(.top, 6)

            statusRow(done: state.shortcutsInstalled,
                      doneText: "Shortcuts installed",
                      waitText: "Not installed yet")
        }
    }
}

private struct HowItWorksStep: View {
    var body: some View {
        VStack(spacing: 18) {
            Text("How SlapShift works")
                .font(.slapTitle(size: 24))
                .foregroundStyle(Brand.ink)

            // Video placeholder. Real demo video goes here after we finish the app.
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Brand.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Brand.rule.opacity(0.6), lineWidth: 1)
                    )
                VStack(spacing: 10) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Brand.accent)
                    Text("Demo video coming soon")
                        .font(.slapMeta(size: 11))
                        .foregroundStyle(Brand.mute)
                }
            }
            .frame(maxWidth: 520, maxHeight: 280)
            .aspectRatio(16/9, contentMode: .fit)

            Text("Slap once → mode 1.  Slap twice → mode 2.  Three slaps → mode 3.")
                .font(.slapBody(size: 12))
                .foregroundStyle(Brand.mute)
                .multilineTextAlignment(.center)
        }
    }
}

private struct PaywallStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text("$9.99")
                    .font(.slapDisplay(size: 56))
                    .foregroundStyle(Brand.ink)
                Text("one-time, in-app")
                    .font(.slapBody(size: 12))
                    .foregroundStyle(Brand.mute)
            }

            Text("Less than a sad desk lunch.")
                .font(.slapTitle(size: 18))
                .italic()
                .foregroundStyle(Brand.accent)

            Text("Try free — pay when you're hooked.")
                .font(.slapBody(size: 13))
                .foregroundStyle(Brand.mute)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Button(action: { state.openCheckout() }) {
                    Text("Buy now — $9.99")
                }
                .buttonStyle(InkButtonStyle(fullWidth: true))
                .keyboardShortcut(.return)

                Button("Try free") { state.next() }
                    .buttonStyle(OutlineButtonStyle())
            }
            .frame(maxWidth: 280)

            Button("I already have a license") { state.openLicenseSheet() }
                .buttonStyle(.plain)
                .font(.slapMeta(size: 11))
                .foregroundStyle(Brand.mute)
                .underline()
                .padding(.top, 4)
        }
    }
}

private struct TestSlapStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: state.testSlapDetected ? "checkmark.seal.fill" : "hand.tap")
                .font(.system(size: 56))
                .foregroundStyle(state.testSlapDetected ? Brand.hill : Brand.accent)
            Text(state.testSlapDetected ? "Got it." : "Slap your MacBook")
                .font(.slapTitle(size: 24))
                .foregroundStyle(Brand.ink)
            Text(state.testSlapDetected
                 ? "SlapShift is listening. Hit Finish to start using it."
                 : "Give it one good slap on the palm rest. We'll know when we feel it.")
                .font(.slapBody(size: 13))
                .foregroundStyle(Brand.mute)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 440)
        }
    }
}

// MARK: - Small shared bits

@ViewBuilder
private func statusRow(done: Bool, doneText: String, waitText: String) -> some View {
    HStack(spacing: 6) {
        Image(systemName: done ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(done ? Brand.hill : Brand.whisper)
        Text(done ? doneText : waitText)
            .font(.slapMeta(size: 11))
            .foregroundStyle(Brand.mute)
    }
    .padding(.top, 4)
}

private struct LabeledField: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.slapMeta(size: 10))
                .tracking(0.1)
                .foregroundStyle(Brand.mute)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15, design: .default))
                .foregroundStyle(Brand.ink)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Brand.paper)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Brand.rule.opacity(0.6), lineWidth: 1)
                )
        }
    }
}

private struct StepDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Brand.accent
                          : i < current ? Brand.mute.opacity(0.5)
                          : Brand.rule.opacity(0.5))
                    .frame(width: i == current ? 18 : 6, height: 6)
                    .animation(.easeOut(duration: 0.2), value: current)
            }
        }
    }
}

// MARK: - State

@MainActor
final class OnboardingState: ObservableObject {

    enum Step: Int, CaseIterable {
        case welcome, signin, name, usage, permission, shortcuts, howItWorks, paywall, testSlap
        var index: Int { rawValue }
    }

    @Published var step: Step = .welcome

    // Identity (Phase 1: stub; Phase 2: real Supabase OAuth)
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var provider: AuthProvider? = nil
    @Published var userId: String? = nil
    @Published var signingIn: Bool = false
    @Published var pendingProvider: AuthProvider? = nil
    @Published var signInError: String? = nil

    // Multi-select usage
    @Published var usage: Set<String> = []

    // Existing wiring
    @Published var permissionGranted: Bool = false
    @Published var shortcutsInstalled: Bool = false
    @Published var testSlapDetected: Bool = false

    // Callbacks wired by AppDelegate.
    var openInputMonitoringSettings: () -> Void = {}
    var installDefaultShortcuts: () -> Void = {}
    var openCheckout: () -> Void = {}
    var openLicenseSheet: () -> Void = {}

    private let authService: AuthService

    // No default arg here — StubAuthService() is @MainActor-isolated, and a
    // default value would try to construct it from a nonisolated context.
    // AppDelegate (the only call site) is @MainActor and passes one in.
    init(authService: AuthService) {
        self.authService = authService
    }

    // MARK: - Navigation

    func next() {
        guard let nextStep = Step(rawValue: step.rawValue + 1) else { return }
        step = nextStep
    }

    func back() {
        guard let prevStep = Step(rawValue: step.rawValue - 1) else { return }
        step = prevStep
    }

    /// Continue button enablement per step. Steps without explicit gates (the
    /// CTAs the user just visited) always advance; gated steps require their
    /// own preconditions before the footer Continue lights up.
    var canAdvance: Bool {
        switch step {
        case .welcome:     return true
        case .signin:      return provider != nil
        case .name:        return !name.trimmingCharacters(in: .whitespaces).isEmpty
                                && email.contains("@") && email.contains(".")
        case .usage:       return !usage.isEmpty
        case .permission:  return permissionGranted
        case .shortcuts:   return shortcutsInstalled
        case .howItWorks:  return true
        case .paywall:     return true  // footer hidden; PaywallStep has its own CTAs
        case .testSlap:    return testSlapDetected
        }
    }

    // MARK: - Usage multi-select

    func toggleUsage(_ id: String) {
        if usage.contains(id) {
            usage.remove(id)
        } else {
            usage.insert(id)
        }
    }

    // MARK: - Sign-in flow

    func signIn(with provider: AuthProvider) async {
        guard !signingIn else { return }
        signingIn = true
        pendingProvider = provider
        signInError = nil
        do {
            let identity = try await authService.signIn(with: provider)
            self.provider = identity.provider
            self.userId = identity.userId
            // Pre-fill the name step from the provider response when available.
            // The user can still edit before continuing.
            if let displayName = identity.displayName, name.isEmpty {
                name = displayName
            }
            if email.isEmpty {
                email = identity.email
            }
            signingIn = false
            pendingProvider = nil
            next()
        } catch {
            signingIn = false
            pendingProvider = nil
            signInError = error.localizedDescription
        }
    }
}
