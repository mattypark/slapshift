// OnboardingView — first-run flow.
//
// Step map (left→right):
//   welcome      — centered logo + "Slap your Mac, workflow maxed." + Continue
//   name         — "What should we call you?" + email (for receipt + updates)
//   usage        — multi-select cards: what will you use this for
//   permission   — grant Input Monitoring (motion sensor)
//   demoOne      — "Slap your MacBook once" → a real example mode fires
//   demoTwo      — "Slap your MacBook twice" → a different example mode fires
//   demoThree    — "Slap three times" → a third example mode fires
//   customize    — "You can edit all of this in Settings"
//   tutorial     — paged video-placeholder slides (Willow-style)
//   paywall      — $9.99 one-time, Buy now (with optional promo)
//   activated    — "Hey, $name. You're all set." post-purchase celebration → home
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
// Identity: name + email captured on the NameStep. Email is the durable
// handle for the license + mailing list (Resend). No SSO — license keys
// are emailed after Stripe Checkout completes.

import SwiftUI

struct OnboardingView: View {

    @ObservedObject var state: OnboardingState

    var onFinish: () -> Void

    /// True after the user has been parked on a slap-demo step for 20 seconds
    /// without succeeding. Lets us surface a Skip escape hatch so a flaky
    /// accelerometer reading doesn't trap the buyer on the gesture demo.
    /// Resets every time `state.step` changes — see `.task(id:)` below.
    @State private var skipVisible: Bool = false

    /// Seconds the user has to spend stuck on a demo step before Skip fades in.
    private let skipDelaySeconds: UInt64 = 20

    var body: some View {
        ZStack(alignment: .top) {
            Brand.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 28)
                    .padding(.top, 18)

                // Flexible top + bottom spacers center the content
                // geometrically between header and footer. The header
                // (logo + step dots) is always pinned at the top regardless
                // of how the content vertically composes — so the logo
                // stays in its top-left anchor while the welcome headline
                // sits dead-center in the available content well.
                Spacer(minLength: 0)

                content
                    .padding(.horizontal, 48)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                footer
                    .padding(.horizontal, 28)
                    .padding(.bottom, 22)
            }
        }
        .frame(minWidth: 560, minHeight: 520)
        // Reset + arm the skip timer on every step change. Cancels automatically
        // when the step changes again (SwiftUI restarts the task), so leaving a
        // demo step early correctly cancels the pending Skip reveal.
        .task(id: state.step) {
            skipVisible = false
            guard Self.isDemoStep(state.step) else { return }
            do {
                try await Task.sleep(nanoseconds: skipDelaySeconds * 1_000_000_000)
                withAnimation(.easeInOut(duration: 0.35)) {
                    skipVisible = true
                }
            } catch {
                // Cancelled (step changed). Nothing to do.
            }
        }
    }

    private static func isDemoStep(_ step: OnboardingState.Step) -> Bool {
        switch step {
        case .demoOne, .demoTwo, .demoThree: return true
        default: return false
        }
    }

    // MARK: - Header (logo + progress dots)

    private var header: some View {
        HStack {
            BrandLogo(height: 88)
            Spacer()
            StepDots(current: state.step.index, total: OnboardingState.Step.allCases.count)
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var content: some View {
        switch state.step {
        case .welcome:     WelcomeStep()
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
        case .activated:   ActivatedStep(state: state, onFinish: onFinish)
        }
    }

    // MARK: - Footer (Back + Continue / Finish)

    private var footer: some View {
        HStack(spacing: 12) {
            if state.step != .welcome && state.step != .activated {
                Button("Back") { state.back() }
                    .buttonStyle(OutlineButtonStyle())
                    .keyboardShortcut(.escape)
            }

            Spacer()

            // Steps with their own primary CTAs (paywall has Buy/Try free,
            // activated has Take me home) suppress the global Continue
            // button so we don't end up with two competing primary actions
            // on screen.
            if state.step != .paywall && state.step != .activated {
                // Skip escape hatch — only on slap-demo steps, only after the
                // user has been stuck for `skipDelaySeconds` without nailing
                // the count, and only while Continue is still gated. Fades in
                // so it doesn't look like a permanent first-class action.
                if Self.isDemoStep(state.step) && skipVisible && !state.canAdvance {
                    Button("Skip") { state.next() }
                        .buttonStyle(OutlineButtonStyle())
                        .transition(.opacity)
                }

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

private struct NameStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text("Tell us where to send your license")
                    .font(.slapTitle(size: 24))
                    .foregroundStyle(Brand.ink)
                Text("Your license key arrives by email. We'll also let you know when new stuff ships.")
                    .font(.slapBody(size: 12))
                    .foregroundStyle(Brand.mute)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            VStack(spacing: 14) {
                // onSubmit on both fields lets the user press Enter while
                // typing to advance, instead of having to mouse over to
                // Continue. The shared `submitIfAble` callback no-ops when
                // the form is still invalid so an early Enter doesn't skip
                // past validation.
                LabeledField(label: "Name", text: $state.name, placeholder: "John",
                             onSubmit: { submitIfAble() })
                LabeledField(label: "Email", text: $state.email, placeholder: "you@example.com",
                             onSubmit: { submitIfAble() })
            }
            .frame(maxWidth: 380)
        }
        .frame(maxWidth: 480)
    }

    private func submitIfAble() {
        if state.canAdvance { state.next() }
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
        ("other",    "sparkles",             "Other",             "Something else — tell us below."),
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

            // "Other" branch: when the user picks the catch-all card, ask them
            // what it actually is. The free-text answer ships to Supabase
            // alongside the structured usage tags so we can read what real
            // users want and add it as a first-class card later.
            if state.usage.contains("other") {
                LabeledField(
                    label: "Why other?",
                    text: $state.otherUsageDetail,
                    placeholder: "Tell us what you'll use it for",
                    onSubmit: { if state.canAdvance { state.next() } }
                )
                .frame(maxWidth: 520)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: state.usage.contains("other"))
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

            // Inline license activation — for buyers who already paid and
            // have the key from their Resend email. Lives right under the
            // promo code so it's discoverable without needing to find the
            // "I already have a license" link. Resilient fallback when the
            // slapshift:// auto-activate from /success didn't fire.
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        if state.licenseInputKey.isEmpty {
                            Text("License key (if you already paid)")
                                .font(.slapBody(size: 13))
                                .foregroundStyle(Brand.ink.opacity(0.42))
                                .padding(.horizontal, 12)
                                .allowsHitTesting(false)
                        }
                        TextField("", text: $state.licenseInputKey)
                            .textFieldStyle(.plain)
                            .font(.slapBody(size: 13))
                            .foregroundStyle(Brand.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .disabled(state.licenseActivating)
                            .onSubmit {
                                if !state.licenseInputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    && !state.licenseActivating {
                                    state.activateLicense()
                                }
                            }
                    }
                    .frame(height: 38)
                    .background(Brand.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Brand.rule.opacity(0.6), lineWidth: 1)
                    )
                    .cornerRadius(6)

                    Button(state.licenseActivating ? "…" : "Activate") {
                        state.activateLicense()
                    }
                    .buttonStyle(OutlineButtonStyle())
                    .disabled(
                        state.licenseActivating ||
                        state.licenseInputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }

                if let err = state.licenseActivationError {
                    Text(err)
                        .font(.slapMeta(size: 10))
                        .foregroundStyle(Brand.accent)
                }
            }
            .frame(maxWidth: 280)

            Button("Other options") { state.openLicenseSheet() }
                .buttonStyle(.plain)
                .font(.slapMeta(size: 11))
                .foregroundStyle(Brand.mute)
                .underline()
                .padding(.top, 4)
        }
    }
}

// MARK: - Activated (post-purchase celebration)
//
// Reached after the buyer pays on the Stripe Checkout page, the webhook mints
// the license key, the /success page redirects via the slapshift:// custom
// scheme, and LicenseManager.tryActivate flips the state to .licensed. The
// AppDelegate watches that state during onboarding and advances the step to
// `.activated` once the flip happens — so the buyer lands here automatically
// without manually clicking anything. The Continue CTA dismisses the
// onboarding window and opens the HomeWindow.
private struct ActivatedStep: View {
    @ObservedObject var state: OnboardingState
    var onFinish: () -> Void

    private var firstName: String {
        let trimmed = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "friend" }
        // Use the first token only — "Matthew Park" → "Matthew" — so the
        // celebration headline reads like a real greeting, not a roll call.
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }

    var body: some View {
        VStack(spacing: 22) {
            // Big seal/checkmark in accent red, mirroring the demo-success state.
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Brand.accent)

            (Text("Hey, ").foregroundColor(Brand.ink)
             + Text(firstName).italic().foregroundColor(Brand.accent)
             + Text(".").foregroundColor(Brand.ink))
                .font(.slapDisplay(size: 44))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("You're all set.")
                .font(.slapTitle(size: 22))
                .foregroundStyle(Brand.ink)

            Text("Your license is live. Three modes are loaded and ready — slap your MacBook to switch between them anytime.")
                .font(.slapBody(size: 13))
                .foregroundStyle(Brand.mute)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 460)

            Button(action: onFinish) {
                Text("Take me to my home")
            }
            .buttonStyle(InkButtonStyle(fullWidth: true))
            .keyboardShortcut(.return)
            .frame(maxWidth: 280)
            .padding(.top, 4)
        }
        .frame(maxWidth: 520)
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
    /// Fired when the user presses Return inside the field. Lets parent
    /// steps advance onboarding without forcing the user over to Continue.
    var onSubmit: () -> Void = {}

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
                    .onSubmit(onSubmit)
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
        case welcome, name, usage, permission,
             demoOne, demoTwo, demoThree, tutorial, customize, paywall,
             activated
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

    // Identity — name + email collected on NameStep. Email is the license
    // recipient and the handle used for product update emails (Resend).
    @Published var name: String = ""
    @Published var email: String = ""

    // Multi-select usage
    @Published var usage: Set<String> = []

    /// Free-text answer when the user picks the "other" card on the usage
    /// step. Required (non-empty) before Continue can advance from `.usage`
    /// when "other" is selected. Sent to Supabase alongside the structured
    /// tags so we can read what real users want.
    @Published var otherUsageDetail: String = ""

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

    /// Inline "I already have a license" entry on the paywall. Lets a buyer
    /// who paid (and got the key by email) activate without going through
    /// Stripe Checkout again — critical fallback when the slapshift:// deep
    /// link from /success doesn't fire (browser blocked it, app wasn't
    /// running, they paid on a different machine, etc.).
    @Published var licenseInputKey: String = ""
    @Published var licenseActivating: Bool = false
    @Published var licenseActivationError: String? = nil

    // Callbacks wired by AppDelegate.
    var openInputMonitoringSettings: () -> Void = {}
    /// Called when the user taps "Buy now". The `promoCode` argument is the
    /// applied (validated) code, or nil if no code was applied. AppDelegate
    /// forwards it to Stripe Checkout as a query parameter.
    var openCheckout: (String?) -> Void = { _ in }
    var openLicenseSheet: () -> Void = {}
    /// Inline license activation. Reads `licenseInputKey`, calls
    /// LicenseManager.tryActivate. On success the existing licenseManager
    /// subscription advances the step to .activated automatically. On
    /// failure, populates `licenseActivationError`.
    var activateLicense: () -> Void = {}

    /// Best-effort POST of the onboarding profile (name + email + usage
    /// tags + optional "other" detail) to the Supabase-backed /api/profile
    /// endpoint. Fired once when the user advances out of the `.usage` step
    /// — that's the first point where we have name, email, AND the usage
    /// answer, and it captures the user even if they bail before paying.
    /// Wired by AppDelegate. Failures are logged, never surfaced to the
    /// user; the onboarding flow continues regardless.
    var submitProfile: () -> Void = {}

    /// Tracks whether `submitProfile` has fired for this onboarding session.
    /// Prevents re-POSTing every time the user clicks Back→Continue across
    /// `.usage`. Reset only by relaunch (a new OnboardingState).
    private var profileSubmitted: Bool = false

    // MARK: - Navigation

    func next() {
        // Capture-on-leave-usage: first time we advance off the usage step,
        // POST the collected profile so the user is in the mailing list even
        // if they never finish onboarding.
        if step == .usage && !profileSubmitted {
            profileSubmitted = true
            submitProfile()
        }
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
        case .name:        return isNameValid && isEmailValid
        case .usage:
            guard !usage.isEmpty else { return false }
            // If "Other" is selected, require a non-empty explanation.
            if usage.contains("other") {
                return !otherUsageDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return true
        case .permission:  return permissionGranted
        case .demoOne:     return demoOneResult == .success
        case .demoTwo:     return demoTwoResult == .success
        case .demoThree:   return demoThreeResult == .success
        case .customize:   return true
        case .tutorial:    return true
        case .paywall:     return true  // footer hidden; PaywallStep has its own CTAs
        case .activated:   return true  // footer hidden; ActivatedStep has its own CTA
        }
    }

    // MARK: - Identity validation

    var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Cheap sanity check on email. Real validation lives at Stripe + the
    /// /api/checkout route; this just blocks "Continue" on obviously bad
    /// input (no @, no domain, whitespace, etc.) so we don't ship garbage
    /// addresses to the mailing list. Server validates again before use.
    var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 5, trimmed.count <= 254 else { return false }
        guard !trimmed.contains(" ") else { return false }
        guard let at = trimmed.firstIndex(of: "@") else { return false }
        let local = trimmed[..<at]
        let domain = trimmed[trimmed.index(after: at)...]
        guard !local.isEmpty, !domain.isEmpty else { return false }
        guard domain.contains(".") else { return false }
        guard !domain.hasPrefix("."), !domain.hasSuffix(".") else { return false }
        return true
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
}
