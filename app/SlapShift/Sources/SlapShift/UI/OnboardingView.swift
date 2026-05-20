// OnboardingView — first-run 4-step flow.
//
// Step 1: Welcome           — what SlapShift is, what it'll need permission for
// Step 2: Input Monitoring  — grant in System Settings, we open the pane for you
// Step 3: Shortcuts         — install the 3 default .shortcut files into Shortcuts.app
// Step 4: Test slap         — wait for the user to actually slap once before finishing
//
// This is a STUB. Wiring to AppDelegate / OnboardingState happens in the next pass —
// today the views render, the buttons fire callbacks, and step transitions work.
// The "did the user actually grant permission?" / "did the shortcut install land?" checks
// are placeholder closures the caller provides.
//
// Paywall is intentionally NOT part of onboarding. Per the revised license flow,
// onboarding ends → SlapShift runs in trial → paywall appears after the first
// successful slap. Keeps onboarding focused on "make the thing work."

import SwiftUI

struct OnboardingView: View {

    @ObservedObject var state: OnboardingState

    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)

            footer
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .background(.thinMaterial)
        }
        .frame(width: 560, height: 460)
    }

    @ViewBuilder
    private var content: some View {
        switch state.step {
        case .welcome:     WelcomeStep()
        case .permission:  PermissionStep(state: state)
        case .shortcuts:   ShortcutsStep(state: state)
        case .testSlap:    TestSlapStep(state: state)
        }
    }

    private var footer: some View {
        HStack {
            StepDots(current: state.step.index, total: OnboardingState.Step.allCases.count)
            Spacer()
            if state.step != .welcome {
                Button("Back") { state.back() }
                    .keyboardShortcut(.escape)
            }
            Button(state.step == .testSlap ? "Finish" : "Continue") {
                if state.step == .testSlap {
                    onFinish()
                } else {
                    state.next()
                }
            }
            .keyboardShortcut(.return)
            .disabled(!state.canAdvance)
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Steps

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(.tint)
            Text("Welcome to SlapShift")
                .font(.largeTitle.weight(.semibold))
            Text("Slap your MacBook to launch your apps, close distractions, and shift into focus.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
            Text("Next, we'll set up two things: permission to read motion, and three starter modes.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
    }
}

private struct PermissionStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Grant Input Monitoring")
                .font(.title2.weight(.semibold))
            Text("SlapShift reads the motion sensor in your MacBook to detect a slap. macOS treats motion data as input, so it needs Input Monitoring permission.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 460)

            Button("Open System Settings") {
                state.openInputMonitoringSettings()
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)

            HStack(spacing: 6) {
                Image(systemName: state.permissionGranted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(state.permissionGranted ? .green : .secondary)
                Text(state.permissionGranted ? "Permission granted" : "Waiting for permission...")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
    }
}

private struct ShortcutsStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Install your starter shortcuts")
                .font(.title2.weight(.semibold))
            Text("SlapShift ships with three Shortcuts — Coding, Apply, and Wind Down — that handle quitting apps and entering Focus modes. We'll add them to your Shortcuts library.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 460)

            Button("Install Shortcuts") {
                state.installDefaultShortcuts()
            }
            .buttonStyle(.bordered)
            .disabled(state.shortcutsInstalled)
            .padding(.top, 4)

            HStack(spacing: 6) {
                Image(systemName: state.shortcutsInstalled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(state.shortcutsInstalled ? .green : .secondary)
                Text(state.shortcutsInstalled ? "Shortcuts installed" : "Not installed yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
    }
}

private struct TestSlapStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: state.testSlapDetected ? "checkmark.seal.fill" : "hand.tap")
                .font(.system(size: 56))
                .foregroundStyle(state.testSlapDetected ? Color.green : Color.accentColor)
            Text(state.testSlapDetected ? "Got it." : "Slap your MacBook")
                .font(.title2.weight(.semibold))
            Text(state.testSlapDetected
                 ? "SlapShift is listening. Hit Finish to start using it."
                 : "Give it one good slap on the palm rest. We'll know when we feel it.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
        }
    }
}

// MARK: - Step dots

private struct StepDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - State

final class OnboardingState: ObservableObject {

    enum Step: Int, CaseIterable {
        case welcome, permission, shortcuts, testSlap
        var index: Int { rawValue }
    }

    @Published var step: Step = .welcome
    @Published var permissionGranted: Bool = false
    @Published var shortcutsInstalled: Bool = false
    @Published var testSlapDetected: Bool = false

    // Wired by AppDelegate. Stubbed here so SwiftUI previews compile.
    var openInputMonitoringSettings: () -> Void = {}
    var installDefaultShortcuts: () -> Void = {}

    func next() {
        guard let nextStep = Step(rawValue: step.rawValue + 1) else { return }
        step = nextStep
    }

    func back() {
        guard let prevStep = Step(rawValue: step.rawValue - 1) else { return }
        step = prevStep
    }

    /// Continue button is gated per-step so users can't skip past a gate that hasn't been
    /// satisfied (e.g. you can't leave the permission step until permission is granted).
    var canAdvance: Bool {
        switch step {
        case .welcome:    return true
        case .permission: return permissionGranted
        case .shortcuts:  return shortcutsInstalled
        case .testSlap:   return testSlapDetected
        }
    }
}
