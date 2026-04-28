import SwiftUI

// MARK: - Buttons

enum MRButtonVariant {
    case primary       // アクセント塗り、白文字 — 主要 CTA
    case secondary     // 薄背景、テキスト色 — 中立アクション
    case ghost         // 背景なし、薄ボーダー — 補助
    case destructive   // 赤塗り — 削除系
    case success       // 緑塗り — 完了/有効
}

enum MRButtonSize {
    case xs            // 高さ 22 / フォント 10.5
    case sm            // 高さ 26 / フォント 11.5  (デフォルト)
    case md            // 高さ 30 / フォント 12.5

    var height: CGFloat {
        switch self {
        case .xs: return 22
        case .sm: return 26
        case .md: return 30
        }
    }
    var font: CGFloat {
        switch self {
        case .xs: return 10.5
        case .sm: return 11.5
        case .md: return 12.5
        }
    }
    var hPadding: CGFloat {
        switch self {
        case .xs: return 9
        case .sm: return 12
        case .md: return 14
        }
    }
}

struct MRButtonStyle: ButtonStyle {
    var variant: MRButtonVariant = .primary
    var size: MRButtonSize = .sm

    func makeBody(configuration: Configuration) -> some View {
        let palette = colors(for: variant)
        return configuration.label
            .font(.system(size: size.font, weight: .semibold))
            .foregroundStyle(palette.fg)
            .padding(.horizontal, size.hPadding)
            .frame(height: size.height)
            .background(Capsule().fill(palette.bg))
            .overlay(Capsule().stroke(palette.border, lineWidth: 0.6))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.85), value: configuration.isPressed)
    }

    private struct Palette { let fg: Color; let bg: Color; let border: Color }

    private func colors(for variant: MRButtonVariant) -> Palette {
        switch variant {
        case .primary:
            return Palette(fg: .white, bg: MRTheme.accent, border: MRTheme.accent.opacity(0.6))
        case .secondary:
            return Palette(fg: Color.primaryText, bg: MRTheme.Surface.inset, border: MRTheme.Border.line)
        case .ghost:
            return Palette(fg: Color.secondaryText, bg: .clear, border: MRTheme.Border.hairline)
        case .destructive:
            return Palette(fg: .white, bg: MRTheme.red.opacity(0.85), border: MRTheme.red.opacity(0.5))
        case .success:
            return Palette(fg: .white, bg: MRTheme.green.opacity(0.85), border: MRTheme.green.opacity(0.5))
        }
    }
}

extension ButtonStyle where Self == MRButtonStyle {
    static func mr(_ variant: MRButtonVariant = .primary, size: MRButtonSize = .sm) -> MRButtonStyle {
        MRButtonStyle(variant: variant, size: size)
    }
}

// MARK: - Icon button (square w/ rounded corners)

struct MRIconButtonStyle: ButtonStyle {
    var tint: Color = .secondaryText
    var dimension: CGFloat = 28
    var emphasized: Bool = false   // true なら押下強調

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: dimension, height: dimension)
            .background(
                RoundedRectangle(cornerRadius: MRTheme.Radius.sm, style: .continuous)
                    .fill(emphasized ? tint.opacity(0.12) : MRTheme.Surface.inset)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MRTheme.Radius.sm, style: .continuous)
                    .stroke(emphasized ? tint.opacity(0.3) : MRTheme.Border.line, lineWidth: 0.5)
            )
            .opacity(configuration.isPressed ? 0.65 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == MRIconButtonStyle {
    static func mrIcon(tint: Color = .secondaryText, dimension: CGFloat = 28, emphasized: Bool = false) -> MRIconButtonStyle {
        MRIconButtonStyle(tint: tint, dimension: dimension, emphasized: emphasized)
    }
}

// MARK: - Close button (top-right "x")

struct MRCloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
        }
        .buttonStyle(.mrIcon(tint: .secondaryText, dimension: 24))
        .keyboardShortcut(.cancelAction)
        .help("閉じる")
    }
}

// MARK: - Pill / Badge

struct MRPill: View {
    enum Style {
        case neutral, success, warning, danger, info, accent
    }
    let label: String
    var systemImage: String? = nil
    var style: Style = .neutral

    var body: some View {
        let (fg, bg) = colors()
        HStack(spacing: 4) {
            if let icon = systemImage {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            } else {
                Circle().fill(fg).frame(width: 5, height: 5)
            }
            Text(label)
                .font(.system(size: MRTheme.FontSize.caption, weight: .bold))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(Capsule().fill(bg))
        .overlay(Capsule().stroke(fg.opacity(0.3), lineWidth: 0.5))
    }

    private func colors() -> (Color, Color) {
        switch style {
        case .neutral: return (Color.secondaryText, MRTheme.Surface.inset)
        case .success: return (MRTheme.green, MRTheme.green.opacity(0.12))
        case .warning: return (MRTheme.yellow, MRTheme.yellow.opacity(0.18))
        case .danger:  return (MRTheme.red, MRTheme.red.opacity(0.12))
        case .info:    return (MRTheme.blue, MRTheme.blue.opacity(0.12))
        case .accent:  return (MRTheme.accent, MRTheme.accentSoft)
        }
    }
}

// MARK: - Card container

struct MRCard<Content: View>: View {
    var selected: Bool = false
    var padding: CGFloat = MRTheme.Space.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: MRTheme.Radius.xl, style: .continuous)
                    .fill(selected ? MRTheme.Surface.cardSelected : MRTheme.Surface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MRTheme.Radius.xl, style: .continuous)
                    .stroke(selected ? MRTheme.Border.accent : MRTheme.Border.hairline, lineWidth: 0.7)
            )
    }
}

// MARK: - Section heading

struct MRSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: MRTheme.FontSize.caption, weight: .bold))
            .foregroundStyle(Color.secondaryText)
            .tracking(0.4)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Toggle (mod styled, wraps system Toggle)

struct MRToggle: View {
    let title: String
    @Binding var isOn: Bool
    var subtitle: String? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: MRTheme.FontSize.label, weight: .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: MRTheme.FontSize.footnote))
                        .foregroundStyle(Color.secondaryText)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(MRTheme.accent)
        }
    }
}

// MARK: - Text field with consistent styling

struct MRStyledTextField<Field: View>: View {
    @ViewBuilder var field: () -> Field

    var body: some View {
        field()
            .textFieldStyle(.plain)
            .font(.system(size: MRTheme.FontSize.body))
            .foregroundStyle(Color.primaryText)
            .padding(.horizontal, MRTheme.Space.md + 2)
            .padding(.vertical, MRTheme.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: MRTheme.Radius.md, style: .continuous)
                    .fill(MRTheme.Surface.field)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MRTheme.Radius.md, style: .continuous)
                    .stroke(MRTheme.Border.line, lineWidth: 0.5)
            )
    }
}
