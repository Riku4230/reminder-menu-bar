import AppKit
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "システム"
        case .light: return "ライト"
        case .dark: return "ダーク"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// `NSApp.appearance` に渡す値。nil で OS 設定に従う。
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    enum Kind {
        case success
        case failure
        case info
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let detail: String?
}

final class AppCoordinator: ObservableObject {
    @Published var appearance: AppearanceMode {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }

    @Published var toast: ToastMessage?
    @Published var quickAddToken = UUID()
    @Published var quickAddShouldOpenOptions = false
    @Published var requestedPopoverHeight: CGFloat = 540

    /// サブタスク追加用の Shortcut が Shortcuts.app にインストール済みか。
    /// 初回起動時に CLI で確認し、未導入なら設定パネル等から導線を出す。
    @Published var subtaskShortcutInstalled: Bool = false

    var showPopover: (() -> Void)?

    private var toastTask: Task<Void, Never>?
    private static let appearanceKey = "appearanceMode"

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.appearanceKey) ?? AppearanceMode.system.rawValue
        appearance = AppearanceMode(rawValue: raw) ?? .system
        subtaskShortcutInstalled = ShortcutsBridge.isInstalled()
    }

    /// Shortcuts.app の取り込みダイアログを起動。完了後しばらくしてから状態を再チェックする。
    func installSubtaskShortcut() {
        let opened = ShortcutsBridge.openInstaller()
        if !opened {
            showToast(
                ToastMessage(
                    kind: .failure,
                    title: "ショートカットを開けませんでした",
                    detail: "アプリに同梱された AddSubReminder.shortcut が見つかりません"
                )
            )
            return
        }
        // ユーザーが取り込みを完了するのを待つために少し遅延させて再チェック
        Task { @MainActor in
            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if ShortcutsBridge.isInstalled() {
                    self.subtaskShortcutInstalled = true
                    self.showToast(
                        ToastMessage(
                            kind: .success,
                            title: "サブタスク機能を有効化しました",
                            detail: nil
                        )
                    )
                    return
                }
            }
        }
    }

    /// FDA 設定パネルを開く（サブタスク階層表示の許可導線）
    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    func showQuickAdd(openOptions: Bool = true) {
        quickAddShouldOpenOptions = openOptions
        showPopover?()
        quickAddToken = UUID()
    }

    func showToast(_ message: ToastMessage, duration: UInt64 = 3_200_000_000) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            toast = message
        }
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: duration)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                toast = nil
            }
        }
    }

    func showAddedToast(titles: [String]) {
        let visible = titles.prefix(4).joined(separator: "、")
        let suffix = titles.count > 4 ? " ほか\(titles.count - 4)件" : ""
        showToast(
            ToastMessage(
                kind: .success,
                title: "\(titles.count)件のタスクを追加しました",
                detail: visible + suffix
            )
        )
    }
}
