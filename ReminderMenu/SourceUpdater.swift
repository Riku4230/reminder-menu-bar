import AppKit
import Foundation

/// ソースビルドユーザー向けの「ターミナルから update.sh を実行」導線。
///
/// アプリは `.app` の場所しか知らないので、git clone した場所はユーザーから一度教えてもらう
/// （`@AppStorage("hutchSourceDir")`）。次回以降は保存したパスを使って即実行する。
@MainActor
enum SourceUpdater {
    private static let sourceDirKey = "hutchSourceDir"

    /// 保存済みのリポジトリパス
    static var savedSourceDir: String? {
        let raw = UserDefaults.standard.string(forKey: sourceDirKey)
        guard let raw, !raw.isEmpty else { return nil }
        return raw
    }

    /// ターミナルで update.sh を実行する。リポジトリパスが未登録なら NSOpenPanel で選ばせる。
    /// 実行に失敗した場合 (ユーザーがキャンセル等) は false を返す。
    @discardableResult
    static func runUpdate() -> Bool {
        let dir: String
        if let saved = savedSourceDir, isValidHutchRepo(at: saved) {
            dir = saved
        } else if let picked = pickSourceDirectory() {
            UserDefaults.standard.set(picked, forKey: sourceDirKey)
            dir = picked
        } else {
            return false
        }

        return runScriptInTerminal(dir: dir)
    }

    /// 保存パスをクリア（誤選択した場合のリセット用）
    static func resetSourceDir() {
        UserDefaults.standard.removeObject(forKey: sourceDirKey)
    }

    // MARK: - Validation

    /// 指定パスが Hutch のリポジトリか軽く検証
    /// （`.git` ディレクトリと `scripts/update.sh` の存在を確認）
    private static func isValidHutchRepo(at path: String) -> Bool {
        let fm = FileManager.default
        let gitDir = (path as NSString).appendingPathComponent(".git")
        let updateScript = (path as NSString).appendingPathComponent("scripts/update.sh")
        return fm.fileExists(atPath: gitDir) && fm.fileExists(atPath: updateScript)
    }

    // MARK: - User interaction

    private static func pickSourceDirectory() -> String? {
        let panel = NSOpenPanel()
        panel.title = "Hutch リポジトリのフォルダを選択"
        panel.message = "git clone した Hutch のディレクトリを選んでください。次回以降は記憶されます。"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return nil }
        let path = url.path
        guard isValidHutchRepo(at: path) else {
            // 不正なディレクトリは保存しない
            let alert = NSAlert()
            alert.messageText = "選んだフォルダは Hutch のリポジトリではないようです"
            alert.informativeText = "git clone した Hutch のフォルダ（.git/ と scripts/update.sh があるところ）を選んでください。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return nil
        }
        return path
    }

    // MARK: - Terminal launching

    /// AppleScript で Terminal.app を起動して update.sh を実行する。
    private static func runScriptInTerminal(dir: String) -> Bool {
        let escapedDir = escapeForAppleScript(dir)
        let command = "cd \"\(escapedDir)\" && ./scripts/update.sh"
        let escapedCommand = escapeForAppleScript(command)

        let scriptText = """
        tell application "Terminal"
            activate
            do script "\(escapedCommand)"
        end tell
        """

        var error: NSDictionary?
        guard let script = NSAppleScript(source: scriptText) else { return false }
        script.executeAndReturnError(&error)
        return error == nil
    }

    /// AppleScript の二重引用符エスケープ
    private static func escapeForAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
