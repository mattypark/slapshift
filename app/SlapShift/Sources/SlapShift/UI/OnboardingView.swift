// OnboardingView — first-run flow.
//
// Step map (left→right):
//   welcome      — centered logo + "Slap your Mac, workflow maxed." + Continue
//   signin       — Continue with Google / Continue with Apple
//   name         — "What should we call you?" + email confirmation
//   usage        — multi-select cards: what will you use this for
//   permission   — grant Input Monitoring (motion sensor)
//   demoOne      — "Slap your MacBook once" → a real example mode fires
//   demoTwo      — "Slap your MacBook twice" → a different example mode fires
//   demoThree    — "Slap three times" → a third example mode fires
//   customize    — "You can edit all of this in Settings"
//   tutorial     — paged video-placeholder slides (Willow-style)
//   paywall      — $9.99 one-time, Buy now (with optional promo) → Finish
//
// Demo steps execute REAL modes via ActionExecutor (apps open, URLs open). The
// slap routing in AppDelegate.handleSlap watches the current onboarding step
// and matches event.count against the step's expected count — if they match,
// it fires the demo mode and advances the step. Mismatches show inline help.
//
// Focus mode integration was removed in v1.0; see Modes/Mode.swift for the
// rationale. Shortcuts install step was removed alongside it — there's no
// longer anything for the user to install before they can try the gesture.
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
        case .demoOne:     DemoStep(state: state, expectedCount: 1,
                                    title: "Slap your MacBook once",
                                    subtitle: "Give it one firm slap on the palm rest. We'll confirm we felt it.")
        case .demoTwo:     DemoStep(state: state, expectedCount: 2,
                                    title: "Now slap twice — quickly",
                                    subtitle: "Two slaps in under half a second. Tap-tap. We'll confirm we caught both.")
        case .demoThree:   DemoStep(state: state, expectedCount: 3,
                                    title: "And three slaps — go",
                                    subtitle: "Tap-tap-tap, fast. Three slaps map to a third mode later — let's make sure we feel them.")
        case .customize:   CustomizeStep()
        case .tutorial:    TutorialStep(state: state)
        case .paywall:     PaywallStep(state: state)
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

            // Steps with their own primary CTAs (signin uses SSO buttons,
            // paywall has Buy/Try free) suppress the global Continue button so
            // we don't end up with two competing primary actions on screen.
            if state.step != .signin && state.step != .paywall {
                Button(action: advance) {
                    Text("Continue")
                }
                .buttonStyle(InkButtonStyle())
                .keyboardShortcut(.return)
                .disabled(!state.canAdvance)
                .opacity(state.canAdvance ? 1 : 0.45)
            }
        }
    }

    private func advance() {
        state.next()
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
                Text("First name, nickname — whatever you go by.")
                    .font(.slapBody(size: 12))
                    .foregroundStyle(Brand.mute)
            }

            VStack(spacing: 14) {
                LabeledField(label: "Name", text: $state.name, placeholder: "John")
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
        ("school",   "graduationcap.fill",   "School / applying", "Open your tabs in one gesture."),
        ("writing",  "pencil.and.scribble",  "Writing",           "Quit distractions, open the doc."),
        ("designing","paintpalette.fill",    "Designing",         "Figma + reference tabs."),
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

// MARK: - Demo step
//
// Used for all three demo steps (1/2/3 slaps). Reads the per-step result from
// OnboardingState: nil = waiting, .success = correct count, .wrong(n) = got n
// slaps but we wanted `expectedCount`. On success we show "Got it." and the
// global Continue advances.
private struct DemoStep: View {
    @ObservedObject var state: OnboardingState
    let expectedCount: Int
    let title: String
    let subtitle: String

    private var result: OnboardingState.DemoResult? {
        state.demoResult(for: expectedCount)
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: iconName)
                .font(.system(size: 56))
                .foregroundStyle(iconColor)

            Text(headlineText)
                .font(.slapTitle(size: 24))
                .foregroundStyle(Brand.ink)
                .multilineTextAlignment(.center)

            Text(bodyText)
                .font(.slapBody(size: 13))
                .foregroundStyle(Brand.mute)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 460)

            // Slap-count indicator: a row of dots showing how many slaps this
            // step expects, lit up if the user just nailed it.
            HStack(spacing: 10) {
                ForEach(0..<expectedCount, id: \.self) { i in
                    Circle()
                        .fill(result == .success ? Brand.accent : Brand.rule.opacity(0.55))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.top, 4)
        }
    }

    private var iconName: String {
        switch result {
        case .success:        return "checkmark.seal.fill"
        case .wrong:          return "exclamationmark.triangle.fill"
        case .none:           return "hand.tap"
        }
    }

    private var iconColor: Color {
        switch result {
        case .success: return Brand.hill
        case .wrong:   return Brand.accent
        case .none:    return Brand.accent
        }
    }

    private var headlineText: String {
        switch result {
        case .success: return "Got it. \(expectedCount) slap\(expectedCount > 1 ? "s" : "") detected."
        case .wrong:   return "Almost — try again"
        case .none:    return title
        }
    }

    private var bodyText: String {
        switch result {
        case .success:
            return "Nothing fires yet — we're just teaching the gesture. Once you set up Mode \(expectedCount) and pay, this is when your apps would launch. Hit Continue."
        case .wrong(let got):
            return "We were waiting for \(expectedCount) slap\(expectedCount > 1 ? "s" : "") but you did \(got). Give it another go."
        case .none:
            return subtitle
        }
    }
}

private struct CustomizeStep: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 48))
                .foregroundStyle(Brand.accent)
            Text("Make it yours")
                .font(.slapTitle(size: 26))
                .foregroundStyle(Brand.ink)
            Text("These are the three modes you'll get. Coding, Apply, Wind Down — each one is a bundle of apps, URLs, and shortcuts that fires on the matching slap count. Every mode is fully editable after you grab the app.")
                .font(.slapBody(size: 13))
                .foregroundStyle(Brand.mute)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 480)

            // Three preview cards — purely visual. No editing here; that opens up
            // after purchase via the menu bar Settings window. Onboarding stays
            // a clean linear flow.
            HStack(spacing: 12) {
                miniModeCard(count: 1, name: "Coding",    symbol: "chevron.left.forwardslash.chevron.right")
                miniModeCard(count: 2, name: "Apply",     symbol: "graduationcap")
                miniModeCard(count: 3, name: "Wind Down", symbol: "moon.stars")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: 520)
    }

    private func miniModeCard(count: Int, name: String, symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(Brand.accent)
            Text(name)
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundStyle(Brand.ink)
            Text("\(count) slap\(count > 1 ? "s" : "")")
                .font(.slapMeta(size: 10))
                .foregroundStyle(Brand.mute)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Brand.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Brand.rule.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Tutorial step (paged video placeholders, Willow-style)

private struct TutorialStep: View {
    @ObservedObject var state: OnboardingState

    private let slides: [(title: String, caption: String, symbol: String)] = [
        ("The gesture",
         "A single firm slap on the palm rest. Not the screen, not the keyboard.",
         "hand.tap.fill"),
        ("One slap = your work mode",
         "Open your code editor, terminal, and dev URLs in one shot. Your default coding setup.",
         "chevron.left.forwardslash.chevron.right"),
        ("Two slaps = applications",
         "School apps, job tabs, whatever — fires the second mode in under a second.",
         "graduationcap.fill"),
        ("Three slaps = wind down",
         "End the day: close work apps, open Notes, queue up music. One gesture.",
         "moon.stars.fill"),
    ]

    private var currentSlide: Int { state.tutorialPage }
    private var slide: (title: String, caption: String, symbol: String) {
        slides[min(currentSlide, slides.count - 1)]
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("How it works")
                .font(.slapTitle(size: 22))
                .foregroundStyle(Brand.ink)

            // Video placeholder. Real demo videos will land here later — one
            // per slide. Until then, an icon + caption stands in.
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Brand.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Brand.rule.opacity(0.6), lineWidth: 1)
                    )
                VStack(spacing: 14) {
                    Image(systemName: slide.symbol)
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(Brand.accent)
                    Text("Demo video coming soon")
                        .font(.slapMeta(size: 10))
                        .foregroundStyle(Brand.whisper)
                }
            }
            .frame(maxWidth: 520, maxHeight: 240)
            .aspectRatio(16/9, contentMode: .fit)

            VStack(spacing: 6) {
                Text(slide.title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Brand.ink)
                Text(slide.caption)
                    .font(.slapBody(size: 12))
                    .foregroundStyle(Brand.mute)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
                    .lineSpacing(3)
            }

            // Page indicator + in-step prev/next.
            HStack(spacing: 16) {
                Button {
                    if state.tutorialPage > 0 { state.tutorialPage -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(state.tutorialPage > 0 ? Brand.ink : Brand.rule)
                }
                .buttonStyle(.plain)
                .disabled(state.tutorialPage == 0)

                HStack(spacing: 6) {
                    ForEach(0..<slides.count, id: \.self) { i in
                        Circle()
                            .fill(i == state.tutorialPage ? Brand.accent : Brand.rule.opacity(0.5))
                            .frame(width: 6, height: 6)
                    }
                }

                Button {
                    if state.tutorialPage < slides.count - 1 { state.tutorialPage += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(state.tutorialPage < slides.count - 1 ? Brand.ink : Brand.rule)
                }
                .buttonStyle(.plain)
                .disabled(state.tutorialPage >= slides.count - 1)
            }
            .padding(.top, 4)
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

            // Promo / coupon code — Stripe Checkout enforces the actual discount
            // server-side; this field is a sanity gate + UX hint. The trimmed
            // code is forwarded to /api/checkout as ?promo=… so Stripe can apply
            // the matching Promotion Code on its hosted page.
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        if state.promoCode.isEmpty {
                            Text("Promo code (optional)")
                                .font(.slapBody(size: 13))
                                .foregroundStyle(Brand.ink.opacity(0.42))
                                .padding(.horizontal, 12)
                                .allowsHitTesting(false)
                        }
                        TextField("", text: $state.promoCode)
                            .textFieldStyle(.plain)
                            .font(.slapBody(size: 13))
                            .foregroundStyle(Brand.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .onSubmit { state.applyPromoCode() }
                    }
                    .frame(height: 38)
                    .background(Brand.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Brand.rule.opacity(0.6), lineWidth: 1)
                    )
                    .cornerRadius(6)

                    Button("Apply") { state.applyPromoCode() }
                        .buttonStyle(OutlineButtonStyle())
                }

                switch state.promoStatus {
                case .applied(let code):
                    Text("\(code) — discount applies at checkout")
                        .font(.slapMeta(size: 10))
                        .foregroundStyle(Brand.hill)
                case .invalid(let msg):
                    Text(msg)
                        .font(.slapMeta(size: 10))
                        .foregroundStyle(Brand.accent)
                case .none:
                    EmptyView()
                }
            }
            .frame(maxWidth: 280)

            Button(action: { state.openCheckout(state.appliedPromo) }) {
                Text("Buy now — $9.99")
            }
            .buttonStyle(InkButtonStyle(fullWidth: true))
            .keyboardShortcut(.return)
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
            // macOS 13's TextField ignores .foregroundColor modifiers applied
            // to the `prompt:` Text — the system always paints its own
            // near-white placeholder color regardless of what we set. So we
            // suppress the native placeholder (empty string) and overlay our
            // own greyed Text on top, visible only while the bound text is
            // empty. Allows hit-testing to fall through to the TextField so
            // a click on the placeholder still focuses the field.
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15, design: .default))
                        .foregroundStyle(Brand.ink.opacity(0.42))
                        .allowsHitTesting(false)
                }
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, design: .default))
                    .foregroundStyle(Brand.ink)
            }
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
        case welcome, signin, name, usage, permission,
             demoOne, demoTwo, demoThree, tutorial, customize, paywall
        var index: Int { rawValue }

        /// For demo steps that actually wait on a live slap, how many slaps
        /// this step expects. All three demo steps are interactive now —
        /// the demos detect-only (no apps open), so asking for three slaps
        /// in a row has no friction beyond the gesture itself. Non-demo
        /// steps return nil.
        var expectedSlapCount: Int? {
            switch self {
            case .demoOne:   return 1
            case .demoTwo:   return 2
            case .demoThree: return 3
            default:         return nil
            }
        }
    }

    /// Per-demo-step result. nil = haven't slapped yet on this step.
    enum DemoResult: Equatable {
        case success
        case wrong(Int)  // user slapped n times but step wanted a different n
    }

    /// Promo code validation state. `.applied` means the code passed format
    /// checks and will be forwarded to Stripe Checkout; Stripe itself decides
    /// whether the code is real.
    enum PromoStatus: Equatable {
        case none
        case applied(String)
        case invalid(String)
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

    @Published var permissionGranted: Bool = false

    /// Per-demo-step outcome, keyed by expected slap count.
    @Published var demoOneResult: DemoResult? = nil
    @Published var demoTwoResult: DemoResult? = nil
    @Published var demoThreeResult: DemoResult? = nil

    /// Tutorial step current slide.
    @Published var tutorialPage: Int = 0

    /// Promo / coupon code state. The code itself is plain user input; the
    /// status is set when the user taps Apply. Stripe enforces the actual
    /// discount server-side — this is just a sanity gate so we don't forward
    /// garbage to Checkout.
    @Published var promoCode: String = ""
    @Published var promoStatus: PromoStatus = .none

    // Callbacks wired by AppDelegate.
    var openInputMonitoringSettings: () -> Void = {}
    /// Called when the user taps "Buy now". The `promoCode` argument is the
    /// applied (validated) code, or nil if no code was applied. AppDelegate
    /// forwards it to Stripe Checkout as a query parameter.
    var openCheckout: (String?) -> Void = { _ in }
    var openLicenseSheet: () -> Void = {}

    private let authService: AuthService

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
        case .usage:       return !usage.isEmpty
        case .permission:  return permissionGranted
        case .demoOne:     return demoOneResult == .success
        case .demoTwo:     return demoTwoResult == .success
        case .demoThree:   return demoThreeResult == .success
        case .customize:   return true
        case .tutorial:    return true
        case .paywall:     return true  // footer hidden; PaywallStep has its own CTAs
        }
    }

    // MARK: - Promo code

    /// The validated code if Apply succeeded, else nil. PaywallStep forwards
    /// this to `openCheckout` so the Stripe URL carries `?promo=...`.
    var appliedPromo: String? {
        if case .applied(let code) = promoStatus { return code }
        return nil
    }

    /// Validate the user's promo input. Trims, uppercases, and rejects empty
    /// strings or characters outside [A-Z0-9-_]. Stripe enforces the actual
    /// discount, so the goal here is sanity, not authorization.
    func applyPromoCode() {
        let trimmed = promoCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !trimmed.isEmpty else {
            promoStatus = .invalid("Enter a code")
            return
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let ok = trimmed.unicodeScalars.allSatisfy { allowed.contains($0) } && trimmed.count <= 32
        if ok {
            promoCode = trimmed
            promoStatus = .applied(trimmed)
        } else {
            promoStatus = .invalid("Letters, numbers, - and _ only")
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

    // MARK: - Demo step helpers

    func demoResult(for expectedCount: Int) -> DemoResult? {
        switch expectedCount {
        case 1: return demoOneResult
        case 2: return demoTwoResult
        case 3: return demoThreeResult
        default: return nil
        }
    }

    /// Called by AppDelegate when a slap fires during a demo step. Returns
    /// `true` if the slap matched the step's expected count (caller will run
    /// the demo execution + advance), `false` if mismatched (caller does
    /// nothing else; the inline UI already explains the error).
    @discardableResult
    func recordDemoSlap(actualCount: Int) -> Bool {
        guard let expected = step.expectedSlapCount else { return false }
        let result: DemoResult = (actualCount == expected) ? .success : .wrong(actualCount)
        switch expected {
        case 1: demoOneResult = result
        case 2: demoTwoResult = result
        case 3: demoThreeResult = result
        default: break
        }
        return result == .success
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
            // Pre-fill the name step from the provider response when the
            // identity carries a real display name. Email is intentionally
            // NOT prefilled — the stub returns a placeholder string ("you@
            // example.com") which would land as opaque body text in the
            // field and look like the user already typed it. The user types
            // their real address on the next step instead.
            if let displayName = identity.displayName, name.isEmpty {
                name = displayName
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
