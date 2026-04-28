# Security Policy

## サポート対象

最新の `main` ブランチおよび GitHub Releases に公開されている最新版のみが対象です。古いバージョンの脆弱性報告には対応できない場合があります。

## 脆弱性の報告

セキュリティ上の問題を発見した場合は、**公開 Issue にしないでください**。代わりに以下のいずれかで報告してください。

### 推奨: GitHub Security Advisories

1. リポジトリ右上の **Security** タブ → **Report a vulnerability** から非公開で報告
2. https://github.com/Riku4230/Hutch/security/advisories/new

GitHub Security Advisories は管理者と報告者のみが閲覧できる非公開チャンネルです。修正完了後に CVE 採番と公開のオプションも提供されます。

### 報告に含めてほしい情報

- 影響範囲（どのバージョン / どの機能）
- 再現手順
- 想定される影響（情報漏洩 / 任意コード実行 / 権限昇格 など）
- 可能であれば PoC

## 対応プロセス

1. 受領後 72 時間以内に初期返信
2. 影響範囲の確認と修正方針の検討
3. 修正版のリリース（重大度に応じて 1〜30 日）
4. Security Advisory として公開（報告者の同意のもと）

## 既知のセキュリティ特性

Hutch は OSS で配布される macOS アプリのため、以下を理解した上でご利用ください。

| 項目 | 状態 |
|---|---|
| **コード署名** | 現状は未署名・未公証。推奨インストール方法はソースからのローカルビルドです |
| **API キー保管** | macOS Keychain（Generic Password）にのみ保存、平文ファイルには出さない |
| **AI プロバイダー通信** | プロバイダー固有の URL に直接 HTTPS。中継サーバーなし |
| **ローカル DB アクセス** | 純正リマインダーの SQLite を read-only でスナップショットコピーしてから読む。書き込みなし |
| **外部依存ライブラリ** | なし（Apple フレームワーク + システム SQLite のみ） |
| **Process 実行** | `/usr/bin/shortcuts` と `claude` を `Process.arguments` 配列で起動。シェル経由しないのでコマンドインジェクション不可 |

## 配布とコード署名

Hutch は現在、Apple Developer ID による署名・公証済みビルドを提供していません。

理由:

- プロジェクトが初期 OSS フェーズであるため
- Apple Developer Program 加入前であるため
- まずはソースコードの透明性を重視して公開しているため

推奨される利用方法:

- 安全性を重視する場合は、ソースコードを確認してローカルビルドしてください
- 事前ビルド済み `.dmg` / Homebrew Cask は上級者向けです
- `.dmg` をダウンロードした場合は、各 Release に添付された `Hutch-vX.Y.Z.dmg.sha256` で整合性を確認できます (`shasum -a 256 -c Hutch-vX.Y.Z.dmg.sha256`)
- 起動時に Gatekeeper 警告が表示された場合は、内容を理解した上で操作してください

将来的な予定:

- Developer ID によるコード署名
- Apple notarization
- stapled `.dmg`
- Homebrew Cask の署名済み配布

## 連絡先

セキュリティ以外の問い合わせは [GitHub Issues](https://github.com/Riku4230/Hutch/issues) へ。
