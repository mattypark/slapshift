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
    static let cream         = Color(red: 0.925, green: 0.898, blue: 0.820) // #ece5d1 — matches slapshiftlogo.png backing exactly
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
                    // No blend mode. Brand.cream is tuned to match the PNG's
                    // backing color (#ece5d1) so the logo tile fuses with the
                    // surface and the artwork renders untouched.
                    .blendMode(loaded.useMultiply ? .multiply : .normal)
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

