import AppKit
import Foundation

/// `/usr/bin/shortcuts` CLI のラッパー。
///
/// EventKit はサブタスクの追加 API を持たないため、Shortcuts.app の
/// 「リマインダーを追加」アクションが持つ `parent reminder` フィールドを
/// 経由して書き込む。本アプリにバンドルされた `AddSubReminder.shortcut`
/// をユーザーに 1 度インストールしてもらい、以降は CLI から実行する。
enum ShortcutsBridge {
    /// バンドル / Shortcuts.app に登録される名前
    static let subtaskShortcutName = "ReminderMenu Add Subtask"

    /// バンドル内の `.shortcut` ファイル名（拡張子なし）
    static let bundledShortcutResource = "AddSubReminder"

    enum BridgeError: Error, LocalizedError {
        case shortcutNotInstalled
        case bundledFileMissing
        case executionFailed(Int32, String)

        var errorDescription: String? {
            switch self {
            case .shortcutNotInstalled:
                return "サブタスク用ショートカット \"\(ShortcutsBridge.subtaskShortcutName)\" がインストールされていません。"
            case .bundledFileMissing:
                return "アプリに同梱された AddSubReminder.shortcut が見つかりません。"
            case .executionFailed(let code, let message):
                return "shortcuts コマンドが失敗しました (code=\(code)): \(message)"
            }
        }
    }

    /// 同名の Shortcut が登録済みか
    static func isInstalled() -> Bool {
        guard let stdout = try? runShortcutsCLI(["list"]) else { return false }
        return stdout
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .contains(subtaskShortcutName)
    }

    /// バンドル内の `.shortcut` を Shortcuts.app の取り込みダイアログで開く
    @discardableResult
    static func openInstaller() -> Bool {
        guard let url = Bundle.main.url(
            forResource: bundledShortcutResource,
            withExtension: "shortcut"
        ) else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }

    /// サブタスクを追加。Shortcuts CLI が同期的に終了するまで await する。
    static func addSubtask(parentID: String, title: String, listName: String) async throws {
        guard isInstalled() else {
            throw BridgeError.shortcutNotInstalled
        }

        let payload: [String: String] = [
            "parentID": parentID,
            "title": title,
            "listName": listName
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let inputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReminderMenu-subtask-\(UUID().uuidString).json")
        try data.write(to: inputURL)
        defer { try? FileManager.default.removeItem(at: inputURL) }

        _ = try runShortcutsCLI([
            "run",
            subtaskShortcutName,
            "--input-path", inputURL.path
        ])
    }

    // MARK: - Private

    @discardableResult
    private static func runShortcutsCLI(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let outString = String(data: outData, encoding: .utf8) ?? ""
        let errString = String(data: errData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            let combined = errString.isEmpty ? outString : errString
            throw BridgeError.executionFailed(process.terminationStatus, combined.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return outString
    }
}
