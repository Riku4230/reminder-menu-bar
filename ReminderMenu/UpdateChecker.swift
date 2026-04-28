import Foundation
import SwiftUI

/// GitHub Releases から最新版を取得し、現在のバージョンより新しければユーザーに通知する。
///
/// 通知の方針:
/// - ポップオーバーが「開いた瞬間」にのみダイアログを出す（バックグラウンドで突然出ない）
/// - 「あとで」を選択した場合は同じバージョンに対して 24 時間スキップする
/// - 「開く」を選択した場合は GitHub Release ページをブラウザで開く（自動ダウンロードはしない）
@MainActor
final class UpdateChecker: ObservableObject {
    /// 検出された新バージョン情報。nil なら未検出。
    @Published var availableUpdate: UpdateInfo?

    private let repo = "Riku4230/Hutch"
    private let snoozeDefaultsKey = "updateCheck.snoozedVersion"
    private let snoozeUntilKey = "updateCheck.snoozedUntil"
    private let lastCheckKey = "updateCheck.lastCheckedAt"

    /// 1 日に 1 回だけリモートを叩く
    private let checkInterval: TimeInterval = 60 * 60 * 24

    struct UpdateInfo: Equatable {
        let latestVersion: String
        let releaseURL: URL
        let bodyExcerpt: String?
    }

    /// "What's new" シート用のリリースノート
    struct ReleaseNotes: Equatable {
        let version: String
        let body: String
        let url: URL
    }

    /// アプリ起動時 / popover 表示時に呼ぶ。
    /// 過去 24h 以内に確認済みなら何もしない。
    func checkIfNeeded() async {
        let now = Date()
        let lastChecked = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        guard now.timeIntervalSince(lastChecked) >= checkInterval else { return }

        UserDefaults.standard.set(now, forKey: lastCheckKey)
        await fetchLatest()
    }

    /// テスト用 / ユーザーが手動でチェックしたい場合の入口
    func checkNow() async {
        await fetchLatest()
    }

    /// 指定バージョンの GitHub Release body を取得する（リリースノート表示用）。
    /// 失敗時は nil。`version` は "0.2.1" / "v0.2.1" どちらでも OK。
    func fetchReleaseNotes(for version: String) async -> ReleaseNotes? {
        let tag = version.hasPrefix("v") ? version : "v\(version)"
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/tags/\(tag)") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Hutch", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            return ReleaseNotes(
                version: normalize(release.tag_name),
                body: release.body ?? "",
                url: URL(string: release.html_url) ?? url
            )
        } catch {
            return nil
        }
    }

    /// 「あとで」用。指定バージョンを 24h スキップする。
    func snooze(_ version: String) {
        UserDefaults.standard.set(version, forKey: snoozeDefaultsKey)
        UserDefaults.standard.set(Date().addingTimeInterval(checkInterval), forKey: snoozeUntilKey)
        availableUpdate = nil
    }

    /// 「あとで」状態が有効かどうか
    private func isSnoozed(_ version: String) -> Bool {
        guard
            let snoozedVersion = UserDefaults.standard.string(forKey: snoozeDefaultsKey),
            let snoozedUntil = UserDefaults.standard.object(forKey: snoozeUntilKey) as? Date
        else { return false }
        return snoozedVersion == version && snoozedUntil > Date()
    }

    private func fetchLatest() async {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Hutch", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latest = normalize(release.tag_name)
            let current = normalize(Bundle.main.shortVersion)

            // 新版が無ければ何もしない（snooze もクリア）
            guard latest.isVersionGreater(than: current) else { return }
            // 同じ新版を 24h スキップ中なら今回は出さない
            guard !isSnoozed(latest) else { return }

            self.availableUpdate = UpdateInfo(
                latestVersion: latest,
                releaseURL: URL(string: release.html_url) ?? url,
                bodyExcerpt: release.body?.split(separator: "\n").prefix(8).joined(separator: "\n")
            )
        } catch {
            // 更新確認の失敗はサイレント（オフラインでもアプリは普通に動く）
        }
    }

    /// 「v1.2.3」「1.2.3」「1.2.3-beta1」を比較しやすい "1.2.3" 系に正規化
    private func normalize(_ s: String) -> String {
        var v = s
        if v.hasPrefix("v") || v.hasPrefix("V") { v.removeFirst() }
        return v
    }
}

private struct GitHubRelease: Decodable {
    let tag_name: String
    let html_url: String
    let body: String?
}

extension Bundle {
    /// Info.plist の CFBundleShortVersionString。未設定なら "0.0.0"。
    var shortVersion: String {
        (object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0.0"
    }
}

extension String {
    /// SemVer の数字 3 つ（major.minor.patch）を比較する単純実装。
    /// pre-release 部分は無視する。
    func isVersionGreater(than other: String) -> Bool {
        let lhs = parsedVersionComponents
        let rhs = other.parsedVersionComponents
        for i in 0..<max(lhs.count, rhs.count) {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    private var parsedVersionComponents: [Int] {
        // pre-release / build metadata を落とす
        let cleaned = split(whereSeparator: { $0 == "-" || $0 == "+" }).first.map(String.init) ?? self
        return cleaned.split(separator: ".").map { Int($0) ?? 0 }
    }
}
