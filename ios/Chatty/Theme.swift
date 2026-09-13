import SwiftUI

/// Semantic colour tokens for the Mika chat surface, aligned with the DeepSeek iOS
/// app (spec §2). Views reference these names only — no literal colours, and no
/// `Color.gray`-style one-offs — so the palette can be retargeted in one place
/// once on-device dark-mode screenshots exist.
///
/// Light values are measured from App Store screenshots (see `research.md §3`).
/// Dark values stay on system semantic colours on purpose: every available
/// DeepSeek source is light-mode, so inventing dark hexes would be a guess
/// (spec §2.1, decisions D1/U4).
enum ChattyTheme {
    /// Page background.
    static let background = dynamic(light: 0xFFFFFF, dark: nil, darkFallback: .systemBackground)
    /// Raised surfaces: the composer card, attachment cards.
    static let surface = dynamic(light: 0xFFFFFF, dark: nil, darkFallback: .secondarySystemBackground)
    /// Recessed fills: top-bar circular buttons, attachment tray buttons, inline code.
    static let surfaceMuted = dynamic(light: 0xF2F2F2, dark: nil, darkFallback: .tertiarySystemFill)
    static let separator = dynamic(light: 0xE8E8E8, dark: nil, darkFallback: .separator)

    static let textPrimary = dynamic(light: 0x0F0F0F, dark: nil, darkFallback: .label)
    /// Process-block titles and body, captions and other secondary text.
    ///
    /// The screenshots measure DeepSeek's grey as `#7D7F85`, but that is only
    /// **4.00:1** on white — below WCAG AA for the small text it carries here
    /// (captions, process steps). `#6E7076` measures **4.88:1** and is the closest
    /// tone that clears the bar the spec sets in §2.3.
    static let textSecondary = dynamic(light: 0x6E7076, dark: nil, darkFallback: .secondaryLabel)

    /// Brand accent. `#4D6BFE` is the official token (`--ds-color-brand`); the
    /// screenshots sample bluer (#426EFE) because marketing assets shipped through
    /// a Display P3 → sRGB conversion, so the token wins (research.md §3).
    static let accent = dynamic(light: 0x4D6BFE, dark: 0x6799FE)
    static let onAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .black : .white
    })

    /// User message bubble.
    static let bubbleUser = dynamic(light: 0xEDF3FE, dark: nil, darkFallback: .secondarySystemBackground)
    static let bubbleUserText = textPrimary
    /// Active feature chip: same tint as the user bubble in DeepSeek's design.
    static let chipActiveFill = dynamic(light: 0xEDF3FE, dark: nil, darkFallback: .secondarySystemBackground)
    static let chipActiveText = accent
    static let chipInactiveBorder = dynamic(light: 0xE5E5E5, dark: nil, darkFallback: .separator)

    static let danger = Color(uiColor: .systemRed)

    private static func dynamic(light: Int, dark: Int?, darkFallback: UIColor? = nil) -> Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                if let dark { return UIColor(rgb: dark) }
                if let darkFallback { return darkFallback }
            }
            return UIColor(rgb: light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: Int) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: 1)
    }
}

enum AppTab: String, CaseIterable, Hashable, Codable {
    case activity, chat, projects, settings
}
