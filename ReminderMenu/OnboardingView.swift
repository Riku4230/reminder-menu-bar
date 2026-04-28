import AppKit
import EventKit
import SwiftUI

/// 初回起動ウィザード。リマインダー許可 → サブタスク機能 → FDA → AI の 4 ステップ。
/// 完了状態は AppStorage で永続化。各ステップは「あとで」スキップ可。
/// MainView 側で `hasCompletedOnboarding` を見て表示・非表示を切り替える。
struct OnboardingView: View {
    @EnvironmentObject private var store: ReminderStore
    @EnvironmentObject private var app: AppCoordinator
    @EnvironmentObject private var aiSettings: AISettings

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    /// 現在のステップ（再起動を跨いでも続きから始められるよう AppStorage に保存）
    @AppStorage("onboardingStep") private var stepRaw: Int = 0

    private var step: Step {
        get { Step(rawValue: stepRaw) ?? .welcome }
    }

    private func setStep(_ next: Step) {
        stepRaw = next.rawValue
    }

    enum Step: Int, CaseIterable {
        case welcome
        case subtaskShortcut
        case fullDiskAccess
        case aiProvider

        var title: String {
            switch self {
            case .welcome: return "Hutch へようこそ"
            case .subtaskShortcut: return "サブタスクを使えるようにする"
            case .fullDiskAccess: return "サブタスクを階層表示する"
            case .aiProvider: return "AI モードを使う"
            }
        }

        var subtitle: String {
            switch self {
            case .welcome: return "純正リマインダーをメニューバーから素早く操作"
            case .subtaskShortcut: return "Shortcuts.app に専用ショートカットを取り込みます"
            case .fullDiskAccess: return "純正アプリの DB を読んで階層を表示します"
            case .aiProvider: return "自然言語追加・サブタスク自動生成のために"
            }
        }

        var icon: String {
            switch self {
            case .welcome: return "checklist"
            case .subtaskShortcut: return "list.bullet.indent"
            case .fullDiskAccess: return "lock.open.fill"
            case .aiProvider: return "sparkles"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 22)

            footer
        }
        .frame(width: 372, height: 540)
        .background(MRTheme.Surface.background)
        .onAppear { autoAdvanceIfReady() }
    }

    /// FDA 許可で再起動して戻ってきた直後など、すでに条件を満たしているステップは自動で次へ進める
    private func autoAdvanceIfReady() {
        switch step {
        case .subtaskShortcut where app.subtaskShortcutInstalled:
            setStep(.fullDiskAccess)
        case .fullDiskAccess where store.hasFullDiskAccess:
            setStep(.aiProvider)
        default:
            break
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(MRTheme.accent.opacity(0.14))
                    .frame(width: 56, height: 56)
                Image(systemName: step.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(MRTheme.accent)
            }
            VStack(spacing: 4) {
                Text(step.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                Text(step.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            stepIndicator
        }
        .padding(.top, 28)
        .padding(.bottom, 14)
        .padding(.horizontal, 24)
    }

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? MRTheme.accent : MRTheme.Border.hairline)
                    .frame(width: s == step ? 18 : 8, height: 5)
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: step)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            welcomeStep
        case .subtaskShortcut:
            subtaskShortcutStep
        case .fullDiskAccess:
            fullDiskAccessStep
        case .aiProvider:
            aiProviderStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow(
                icon: "checklist",
                title: "メニューバーから瞬時に追加",
                detail: "Dock を離れずタスクを書いて、書き終わったら閉じるだけ"
            )
            featureRow(
                icon: "sparkles",
                title: "AI が言葉を理解する",
                detail: "「明日 15 時に病院」で日付・メモ・URL まで自動抽出"
            )
            featureRow(
                icon: "list.bullet.indent",
                title: "進捗が見えるタスク管理",
                detail: "未着手 / 進行中 / 完了の 3 状態とサブタスク自動分解"
            )
            featureRow(
                icon: "calendar",
                title: "カレンダーで月を俯瞰",
                detail: "リスト色のドットで予定が一目で分かる"
            )

            actionPrimary(label: "リマインダーへのアクセスを許可") {
                store.requestAccessAndLoad()
                advance()
            }
            .padding(.top, 4)

            Text("初回はシステムのダイアログが出ます。")
                .font(.system(size: 10.5))
                .foregroundStyle(Color.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, 8)
    }

    private var subtaskShortcutStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            paragraph("EventKit にはサブタスクの API が無いため、Shortcuts.app の専用ショートカットを経由してサブタスクを書き込みます。")
            paragraph("「ショートカットをインストール」を押すと Shortcuts.app の取り込みダイアログが開きます。「ショートカットを追加」でセットアップ完了です。")

            statusBadge(
                ok: app.subtaskShortcutInstalled,
                okText: "インストール済み",
                ngText: "未インストール"
            )

            actionPrimary(label: app.subtaskShortcutInstalled
                          ? "再インストールする"
                          : "ショートカットをインストール") {
                app.installSubtaskShortcut()
            }

            Text("既に名前が「ReminderMenu Add Subtask」のショートカットがあれば変更不要です。")
                .font(.system(size: 10.5))
                .foregroundStyle(Color.tertiaryText)
                .padding(.top, 2)
        }
        .padding(.top, 8)
    }

    private var fullDiskAccessStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            paragraph("サブタスクの追加は前ステップだけで動きますが、メニュー内で **親 → 子の階層表示** をするには純正リマインダーの SQLite を読む必要があり、フルディスクアクセスの許可が必要です。")

            // 重要な注意（macOS の TCC 仕様）
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MRTheme.yellow)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text("許可した瞬間に Hutch が再起動します")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(Color.primaryText)
                    Text("これは macOS の仕様（TCC 権限変更で対象アプリが自動終了）です。再起動後は階層表示が有効になります。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .background(MRTheme.yellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MRTheme.yellow.opacity(0.30), lineWidth: 0.5)
            )

            statusBadge(
                ok: store.hasFullDiskAccess,
                okText: "許可済み",
                ngText: "未許可（フラット表示）"
            )

            actionPrimary(label: "システム設定を開く") {
                app.openFullDiskAccessSettings()
            }

            Text("未許可でもサブタスク自体は動作します。純正アプリ・iPhone では正しく階層表示されます。")
                .font(.system(size: 10.5))
                .foregroundStyle(Color.tertiaryText)
                .padding(.top, 2)
        }
        .padding(.top, 8)
    }

    private var aiProviderStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            paragraph("AI モード（自然言語からのリマインダー追加・サブタスク自動生成）は 4 つのプロバイダーから選べます。Claude Code CLI が一番手軽、API 系は自分の API キーが必要です。")

            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(aiReady ? MRTheme.green : Color.tertiaryText)
                Text(currentAIStatus)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primaryText)
                Spacer()
            }
            .padding(10)
            .background(MRTheme.Surface.inset, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            actionPrimary(label: aiReady ? "プロバイダー設定を開く" : "プロバイダーを設定") {
                app.openAISettingsRequest = UUID()
            }

            Text("ここはあとで「⋯ → AI 設定」からも変更できます。")
                .font(.system(size: 10.5))
                .foregroundStyle(Color.tertiaryText)
                .padding(.top, 2)
        }
        .padding(.top, 8)
    }

    private var aiReady: Bool {
        aiSettings.hasAPIKey(aiSettings.providerID)
    }

    private var currentAIStatus: String {
        let provider = aiSettings.providerID
        if provider == .claudeCode {
            return "Claude Code (CLI) を使う設定です"
        }
        if aiSettings.hasAPIKey(provider) {
            return "\(provider.displayName) — API キー設定済み"
        }
        return "\(provider.displayName) — API キー未設定"
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            if step == .welcome {
                ghostButton(label: "スキップ") { complete() }
            } else {
                ghostButton(label: "← 戻る") { back() }
            }
            Spacer()
            primaryButton(
                label: step == .aiProvider ? "完了して始める" : "次へ",
                trailingIcon: step == .aiProvider ? "checkmark" : "arrow.right"
            ) { advance() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(MRTheme.Surface.glass)
        .overlay(alignment: .top) {
            Rectangle().fill(MRTheme.Border.hairline).frame(height: 0.5)
        }
    }

    // MARK: - Buttons

    private func primaryButton(label: String, trailingIcon: String?, action: @escaping () -> Void) -> some View {
        OnboardingPrimaryButton(label: label, trailingIcon: trailingIcon, action: action)
    }

    private func ghostButton(label: String, action: @escaping () -> Void) -> some View {
        OnboardingGhostButton(label: label, action: action)
    }

    // MARK: - Reusable bits

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MRTheme.accent)
                .frame(width: 22, height: 22)
                .background(MRTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(2)
            }
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.primaryText)
            .lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusBadge(ok: Bool, okText: String, ngText: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle.dotted")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ok ? MRTheme.green : Color.tertiaryText)
            Text(ok ? okText : ngText)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.primaryText)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(MRTheme.Surface.inset, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func actionPrimary(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 12.5, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(MRTheme.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                setStep(next)
            }
        } else {
            complete()
        }
    }

    private func back() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                setStep(prev)
            }
        }
    }

    private func complete() {
        hasCompletedOnboarding = true
        // 完了後の再オンボーディングに備えて step は welcome に戻しておく
        stepRaw = 0
    }
}

// MARK: - Reusable buttons

private struct OnboardingPrimaryButton: View {
    let label: String
    let trailingIcon: String?
    let action: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                MRTheme.accent,
                                MRTheme.accent.opacity(isHovering ? 1.0 : 0.92)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(isHovering ? 0.06 : 0))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 0.6)
            )
            .shadow(color: MRTheme.accent.opacity(isHovering ? 0.42 : 0.30), radius: isHovering ? 10 : 6, y: 3)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: isHovering)
            .animation(.spring(response: 0.18, dampingFraction: 0.78), value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .pressEvents(onPress: { isPressed = true }, onRelease: { isPressed = false })
    }
}

private struct OnboardingGhostButton: View {
    let label: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(isHovering ? Color.primaryText : Color.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isHovering ? MRTheme.Surface.inset : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// 押下イベントを取りたい時用の小ヘルパー
private extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}
