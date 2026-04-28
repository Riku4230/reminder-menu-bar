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

    // ---- Semantic surfaces ----
    enum Surface {
        static let background = Color.white.opacity(0.92)
        static let card = Color.black.opacity(0.025)
        static let cardSelected = Color(red: 0.22, green: 0.52, blue: 0.95).opacity(0.06)
        static let inset = Color.black.opacity(0.04)
        static let field = Color.white.opacity(0.85)
        static let glass = Color.white.opacity(0.65)
    }

    enum Border {
        static let hairline = Color.black.opacity(0.07)
        static let line = Color.black.opacity(0.10)
        static let strong = Color.black.opacity(0.18)
        static let accent = Color(red: 0.22, green: 0.52, blue: 0.95).opacity(0.45)
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
