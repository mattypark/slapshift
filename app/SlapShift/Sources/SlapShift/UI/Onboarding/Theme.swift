// Onboarding theme — mirrors web/app/globals.css.
//
// The buyer just came from slapshift.app. The in-app cream-and-red palette,
// transitional serif headlines, and monospace body text are how we keep that
// continuity. Anything sand/red-shifted = brand. Anything dark/system-blue =
// drift, and we don't want drift on the first screen they see.
//
// Fonts: we use SwiftUI's built-in `.serif` (New York) + `.monospaced` (SF Mono)
// designs rather than bundling Newsreader + JetBrains Mono. New York is also
// a transitional serif with an italic — close enough that brand reads as one
// product across web → app without the resource-handling cost. If we ever
// want pixel-perfect parity, this is the seam to swap in custom .ttf loads.

import SwiftUI

enum Brand {
    // Surfaces — straight from the web :root vars.
    static let cream         = Color(red: 0.937, green: 0.914, blue: 0.827) // #efe9d3
    static let creamDeeper   = Color(red: 0.910, green: 0.882, blue: 0.776) // #e8e1c6
    static let paper         = Color(red: 0.964, green: 0.945, blue: 0.871) // #f6f1de
    static let rule          = Color(red: 0.780, green: 0.760, blue: 0.659) // #c7c2a8

    // Text.
    static let ink           = Color(red: 0.059, green: 0.059, blue: 0.055) // #0f0f0e
    static let mute          = Color(red: 0.478, green: 0.459, blue: 0.408) // #7a7568
    static let whisper       = Color(red: 0.659, green: 0.635, blue: 0.576) // #a8a293

    // Accents.
    static let accent        = Color(red: 0.827, green: 0.290, blue: 0.184) // #d34a2f
    static let accentDeep    = Color(red: 0.631, green: 0.227, blue: 0.137) // #a13a23
    static let sun           = Color(red: 0.957, green: 0.722, blue: 0.161) // #f4b829
    static let hill          = Color(red: 0.353, green: 0.478, blue: 0.290) // #5a7a4a
}

// MARK: - Type ramp

extension Font {
    /// Hero title — Newsreader (bundled variable font, opsz 6-72pt, wght
    /// ExtraLight-ExtraBold). Soft transitional serif with a warm, almost
    /// game-credits feel — matches the website's `--font-serif` voice.
    /// Loaded from Resources/Newsreader.ttf via ATSApplicationFontsPath.
    /// Weight is applied with `.weight(...)` on the returned Font so the
    /// variable wght axis interpolates correctly.
    static func slapDisplay(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        Font.custom("Newsreader 16pt", size: size).weight(weight)
    }
    /// Section headline — same Newsreader family as slapDisplay, just smaller.
    static func slapTitle(size: CGFloat = 22) -> Font {
        Font.custom("Newsreader 16pt", size: size).weight(.semibold)
    }
    /// Body text — monospace, same vibe as the website's --font-mono.
    static func slapBody(size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
    /// Small caps / meta line — version strings, "press to continue", etc.
    static func slapMeta(size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

// MARK: - Buttons

/// Big inky primary CTA. Black pill with cream text. Mirrors the "DOWNLOAD FOR MACOS"
/// button on the landing page so the buyer recognizes the affordance.
struct InkButtonStyle: ButtonStyle {
    var fullWidth: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.slapMeta(size: 12))
            .tracking(0.08)
            .textCase(.uppercase)
            .foregroundStyle(Brand.cream)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(configuration.isPressed ? Color.black.opacity(0.85) : Brand.ink)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Secondary outline button — used for "Back", "Skip", "I have a license".
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.slapMeta(size: 12))
            .tracking(0.08)
            .textCase(.uppercase)
            .foregroundStyle(Brand.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Brand.ink.opacity(configuration.isPressed ? 0.4 : 0.8), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(configuration.isPressed ? Brand.creamDeeper : Color.clear)
                    )
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// SSO button (Continue with Google / Apple). White card with provider glyph + label.
/// Same shape as the dark 10x screen, repainted for the cream brand.
struct SSOButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium, design: .default))
            .foregroundStyle(Brand.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Brand.paper)
                    .shadow(color: Color.black.opacity(configuration.isPressed ? 0.04 : 0.08), radius: 6, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Brand.rule.opacity(0.6), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Selectable card (multi-select usage step)

/// Big checkbox-card that toggles state on tap. Used by the "what will you use this for"
/// multi-select grid. Selected = accent border + faint paper fill.
struct SelectableCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(isSelected ? Brand.accent : Brand.mute)
                    .frame(width: 24, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(Brand.ink)
                    Text(subtitle)
                        .font(.slapBody(size: 11))
                        .foregroundStyle(Brand.mute)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Brand.accent : Brand.rule)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Brand.paper : Brand.cream)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Brand.accent : Brand.rule.opacity(0.5),
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Logo mark

/// Tiny pixel-style "SlapShift" mark to anchor the header.
/// Matches the `<SlapShiftLogo />` corner glyph on the website (the red "SlapShift"
/// wordmark with the radiating slap lines). Drawn in SwiftUI as text+symbols so we
/// don't need to bundle an SVG/raster asset for v1.
struct SlapMark: View {
    var size: CGFloat = 28
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                // Three short red rays radiating up-left, like the website.
                ForEach(0..<3) { i in
                    Rectangle()
                        .fill(Brand.accent)
                        .frame(width: size * 0.32, height: size * 0.08)
                        .rotationEffect(.degrees(Double(-30 - i * 18)))
                        .offset(x: -size * 0.55, y: -size * 0.35)
                }
            }
            Text("SlapShift")
                .font(.system(size: size * 0.62, weight: .bold, design: .serif))
                .foregroundStyle(Brand.accent)
        }
        .frame(height: size)
    }
}

/// Real pixel "S" mark logo loaded from Resources/Sslap.png.
/// Falls back to the older slapshiftlogo.png wordmark, then to the SwiftUI-drawn
/// SlapMark, so the header never collapses on a missing-resource bug.
struct BrandLogo: View {
    var height: CGFloat = 28
    var body: some View {
        Group {
            if let loaded = Self.loadBrandImage() {
                Image(nsImage: loaded.image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(height: height)
                    // Multiply lets the PNG's background (cream for slapshiftlogo,
                    // white for Sslap) drop out onto the app's surface cream so the
                    // wordmark reads as painted directly on the canvas instead of
                    // pasted on a slightly off-cream tile. Red strokes survive.
                    .blendMode(.multiply)
                    .opacity(0.92)
            } else {
                SlapMark(size: height)
            }
        }
    }

    private static func loadBrandImage() -> (image: NSImage, useMultiply: Bool)? {
        if let img = loadBundled(name: "slapshiftlogo") {
            return (img, useMultiply: false)
        }
        if let img = loadBundled(name: "Sslap") {
            return (img, useMultiply: true)
        }
        return nil
    }

    private static func loadBundled(name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        return img
    }
}

/// Google "G" mark. Loads Resources/googlelogo.png — Google's actual brand
/// asset — so the "Sign in with Google" button looks like the real thing and
/// not a SwiftUI approximation. Falls back to a hand-drawn SwiftUI G if the
/// PNG is missing from the bundle, so a broken Resources copy phase doesn't
/// leave the button with an empty space.
struct GoogleLogo: View {
    var size: CGFloat = 18

    var body: some View {
        if let url = Bundle.main.url(forResource: "googlelogo", withExtension: "png"),
           let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            GoogleLogoFallback(size: size)
        }
    }
}

/// SwiftUI-drawn fallback for the Google "G" — used only if the bundled PNG
/// is missing. Geometry: SwiftUI Circle trim positions 0 = 3 o'clock, 0.25 = 6,
/// 0.5 = 9, 0.75 = 12. The horizontal blue stem extends from the inner edge
/// of the ring on the right inward to the horizontal center.
private struct GoogleLogoFallback: View {
    var size: CGFloat = 18

    private let blue   = Color(red: 0.259, green: 0.522, blue: 0.957) // #4285F4
    private let red    = Color(red: 0.918, green: 0.263, blue: 0.208) // #EA4335
    private let yellow = Color(red: 0.984, green: 0.737, blue: 0.016) // #FBBC04
    private let green  = Color(red: 0.204, green: 0.659, blue: 0.325) // #34A853

    private var ringDiameter: CGFloat { size * 0.92 }
    private var strokeWidth: CGFloat { size * 0.22 }
    private var outerRadius: CGFloat { ringDiameter / 2 }
    private var innerRadius: CGFloat { outerRadius - strokeWidth }

    var body: some View {
        ZStack {
            // Red top arc: from ~11 o'clock (0.66) sweeping clockwise through
            // 12 and over to ~2 o'clock (0.92). Position 1.0 is 3 o'clock, so
            // stopping at 0.92 leaves a clean gap above the stem entry point.
            arc(from: 0.66, to: 0.92, color: red)

            // Blue right arc: starts JUST below 3 o'clock (0.05) and sweeps
            // down to ~5 o'clock (0.18). The gap from 0.92 → 1.0 → 0.05 is
            // where the stem meets the ring on the right side.
            arc(from: 0.05, to: 0.18, color: blue)

            // Green bottom arc: from ~5 o'clock (0.18) through 6 to ~8 (0.42).
            arc(from: 0.18, to: 0.42, color: green)

            // Yellow left arc: from ~8 o'clock (0.42) up through 9 to ~11 (0.66),
            // meeting the red arc.
            arc(from: 0.42, to: 0.66, color: yellow)

            // Blue horizontal stem. Sits on the vertical midline. Extends from
            // the horizontal center (x = 0) out to the inner edge of the ring
            // on the right (x = innerRadius). Width = innerRadius. Center
            // offset is therefore innerRadius / 2 so the left edge lands at 0.
            Rectangle()
                .fill(blue)
                .frame(width: innerRadius, height: strokeWidth)
                .offset(x: innerRadius / 2, y: 0)
        }
        .frame(width: size, height: size)
    }

    private func arc(from start: CGFloat, to end: CGFloat, color: Color) -> some View {
        Circle()
            .trim(from: start, to: end)
            .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt))
            .frame(width: ringDiameter, height: ringDiameter)
    }
}
