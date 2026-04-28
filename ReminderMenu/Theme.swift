import AppKit
import SwiftUI

enum MRTheme {
    // ---- Brand / accent ----
    static let accent = Color(red: 0.22, green: 0.52, blue: 0.95)
    static let accentSoft = Color(red: 0.22, green: 0.52, blue: 0.95).opacity(0.16)
    static let accentFaint = Color(red: 0.22, green: 0.52, blue: 0.95).opacity(0.08)
    static let blue = Color(red: 0.18, green: 0.56, blue: 0.95)
    static let purple = Color(red: 0.62, green: 0.38, blue: 0.95)
    static let pink = Color(red: 0.95, green: 0.36, blue: 0.58)
    static let green = Color(red: 0.28, green: 0.74, blue: 0.48)
    static let yellow = Color(red: 0.88, green: 0.72, blue: 0.24)
    static let red = Color(red: 0.95, green: 0.22, blue: 0.24)
    static let gray = Color(red: 0.52, green: 0.52, blue: 0.48)

    static let listColors: [Color] = [accent, blue, green, purple, pink, red, yellow, gray]

    // ---- Semantic surfaces (light/dark adaptive) ----
    enum Surface {
        /// ポップオーバー全体の地（VisualEffect の上に重ねる薄い地）
        static let background = Color.adaptive(
            light: NSColor(white: 1.0, alpha: 0.92),
            dark:  NSColor(white: 0.10, alpha: 0.55)
        )
        /// カードや行の控えめなホバー / 選択地
        static let card = Color.adaptive(
            light: NSColor(white: 0.0, alpha: 0.025),
            dark:  NSColor(white: 1.0, alpha: 0.04)
        )
        static let cardSelected = MRTheme.accent.opacity(0.10)
        /// チップ / アイコン丸ボタンの内地（ボタン質感）
        static let inset = Color.adaptive(
            light: NSColor(white: 0.0, alpha: 0.05),
            dark:  NSColor(white: 1.0, alpha: 0.08)
        )
        /// 入力欄 / 浮く面（カプセル / ボックス）
        static let field = Color.adaptive(
            light: NSColor(white: 1.0, alpha: 0.85),
            dark:  NSColor(white: 1.0, alpha: 0.07)
        )
        /// 半透明ガラス（メニューの薄い面）
        static let glass = Color.adaptive(
            light: NSColor(white: 1.0, alpha: 0.6),
            dark:  NSColor(white: 1.0, alpha: 0.06)
        )
    }

    enum Border {
        static let hairline = Color.adaptive(
            light: NSColor(white: 0, alpha: 0.07),
            dark:  NSColor(white: 1, alpha: 0.08)
        )
        static let line = Color.adaptive(
            light: NSColor(white: 0, alpha: 0.10),
            dark:  NSColor(white: 1, alpha: 0.12)
        )
        static let strong = Color.adaptive(
            light: NSColor(white: 0, alpha: 0.18),
            dark:  NSColor(white: 1, alpha: 0.22)
        )
        static let accent = MRTheme.accent.opacity(0.45)
    }

    // ---- Spacing scale ----
    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 20
        static let xxxl: CGFloat = 24
    }

    // ---- Corner radius ----
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 12
        static let xxl: CGFloat = 16
    }

    // ---- Typography (sizes; weight applied at use site) ----
    enum FontSize {
        static let caption: CGFloat = 10
        static let footnote: CGFloat = 11
        static let body: CGFloat = 12
        static let label: CGFloat = 13
        static let title: CGFloat = 15
        static let heading: CGFloat = 17
    }

    static func nsColor(for color: Color) -> NSColor {
        switch color {
        case blue: return NSColor.systemBlue
        case green: return NSColor.systemGreen
        case purple: return NSColor.systemPurple
        case pink: return NSColor.systemPink
        case red: return NSColor.systemRed
        case yellow: return NSColor.systemYellow
        case gray: return NSColor.systemGray
        default: return NSColor.systemOrange
        }
    }
}

extension Color {
    static var primaryText: Color { Color(nsColor: .labelColor) }
    static var secondaryText: Color { Color(nsColor: .secondaryLabelColor) }
    static var tertiaryText: Color { Color(nsColor: .tertiaryLabelColor) }

    /// ライト / ダークアピアランスで自動切り替えされる SwiftUI Color。
    /// dynamicProvider で `appearance.bestMatch(...)` を見て解決する。
    static func adaptive(light: NSColor, dark: NSColor) -> Color {
        let dynamic = NSColor(name: nil) { appearance in
            let darkMatch = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark])
            return darkMatch != nil ? dark : light
        }
        return Color(nsColor: dynamic)
    }
}

extension DateFormatter {
    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    static let dayAndTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "E H:mm"
        return formatter
    }()

    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        return formatter
    }()
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 34, height: 34)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.35), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
