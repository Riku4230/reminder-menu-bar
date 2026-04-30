import AppKit
import SwiftUI

/// アプリを新しいバージョンに更新した直後の初回起動時に表示する "What's new" シート。
///
/// 表示条件は MainView 側で `@AppStorage("lastSeenVersion")` と
/// `Bundle.main.shortVersion` を比較して判定する。閉じると lastSeen を
/// 現在版に更新するので、同じバージョンでは二度目は出ない。
struct WhatsNewView: View {
    let notes: UpdateChecker.ReleaseNotes
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().opacity(0.4)

            ScrollView {
                Text(LocalizedStringKey(displayBody))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.primaryText)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 160, maxHeight: 320)

            Divider().opacity(0.4)

            footer
        }
        .frame(width: 380)
        .background(MRTheme.Surface.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(MRTheme.accent.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MRTheme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Hutch v\(notes.version) にアップデートしました")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                Text(hasReleaseNotes ? "変更点を確認してください" : "リリースノートはまだ取得できていません")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondaryText)
            }

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.secondaryText)
                    .frame(width: 22, height: 22)
                    .background(MRTheme.Surface.inset, in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("閉じる")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                NSWorkspace.shared.open(notes.url)
            } label: {
                Text("リリースページを開く")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onDismiss) {
                Text("OK")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 9)
                    .background(MRTheme.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(MRTheme.Surface.glass)
    }

    private var hasReleaseNotes: Bool {
        !notes.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// body が空でも必ず何か表示するためのフォールバック付き本文
    private var displayBody: String {
        if hasReleaseNotes { return notes.body }
        return """
        Hutch を **v\(notes.version)** に更新しました。

        このバージョンの詳細なリリースノートはまだ GitHub から取得できていません。最新の変更履歴は [リリースページ](\(notes.url.absoluteString)) で確認できます。
        """
    }
}
