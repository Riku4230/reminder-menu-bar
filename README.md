<div align="center">

<img src="docs/images/hero.png" alt="Hutch — AI-powered reminders for macOS menu bar" width="100%" />

# Hutch

**メニューバーに置く、リマインダー専用の小さな棚**

🇯🇵 日本語 · [🇺🇸 English](README.en.md)

[![Latest Release](https://img.shields.io/github/v/release/Riku4230/Hutch?style=flat-square&color=4f7bf3)](https://github.com/Riku4230/Hutch/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/Riku4230/Hutch/total?style=flat-square&color=4f7bf3)](https://github.com/Riku4230/Hutch/releases)
[![License](https://img.shields.io/github/license/Riku4230/Hutch?style=flat-square&color=4f7bf3)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14+-black?style=flat-square&logo=apple)](https://github.com/Riku4230/Hutch/releases/latest)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange?style=flat-square&logo=swift)](https://swift.org)

[**インストール**](#-インストール) ·
[**機能**](#-機能) ·
[**使い方**](#-使い方) ·
[**設計**](#-設計)

</div>

---

純正 Apple リマインダーのデータを **そのまま** メニューバーから扱えます。EventKit で読み書きするので、書いたタスクは iCloud 経由で iPhone / iPad / Mac の純正アプリに即時同期されます。Hutch を消してもデータは純正アプリに残ります。

その上に **AI 入力**、**サブタスク階層**、**3 状態ステータス**、**カレンダー俯瞰** といった、純正リマインダーでは弱い「Mac で素早く書いて閉じる」体験を被せています。

## ⚡ クイックスタート

```bash
brew tap Riku4230/hutch https://github.com/Riku4230/Hutch.git
brew install --cask hutch
```

> 1 行で完了。Homebrew が無い場合は [Releases](https://github.com/Riku4230/Hutch/releases/latest) から `.dmg` をダウンロード。

## ✨ 機能

| | |
|---|---|
| 🪶 **メニューバー常駐** | Dock 非表示、`Fn` ダブルタップ or グローバルショートカットで瞬時に開閉 |
| 🤖 **AI で自然言語追加** | 「明日 15 時に歯医者 https://...」で日付・メモ・URL を自動抽出 |
| 🎯 **3 状態ステータス** | 未着手 / 進行中 / 完了。進行中は `#wip` タグで iCloud 同期 |
| 🌳 **サブタスク階層** | Shortcuts.app 経由で書き込み + SQLite 直読で純正と同じ親子関係 |
| 🪄 **AI でサブタスク自動分解** | 親タスクを 3〜7 件のサブタスクに展開、編集して一括登録 |
| 📅 **カレンダービュー** | 月グリッドにリスト色のドットで予定を俯瞰、日本の祝日対応 |
| 🔔 **メニューバー脈動通知** | アラーム時刻にアイコンが光るだけ、常時表示の数字バッジは無し |
| 🔌 **マルチプロバイダー AI** | Claude Code / Anthropic / OpenAI / Gemini を切替、API キーは Keychain |
| 🌗 **ライト / ダーク / システム追従** | Glass Float デザイン、即時切替 |
| ☁️ **iCloud 共有リスト対応** | 純正アプリで作ったリストはそのまま使える |

## 🚀 インストール

### Homebrew（推奨）

```bash
brew tap Riku4230/hutch https://github.com/Riku4230/Hutch.git
brew install --cask hutch
```

### `.dmg` を直接ダウンロード

[Latest Release](https://github.com/Riku4230/Hutch/releases/latest) から `Hutch-*.dmg` を取得 → 開いて `Hutch.app` を `Applications` にドラッグ。

> 初回起動で Gatekeeper 警告が出たら **システム設定 → プライバシーとセキュリティ → 「このまま開く」** で起動できます。

### ソースからビルド

```bash
git clone https://github.com/Riku4230/Hutch.git
cd Hutch
./scripts/build_app.sh --install
```

要件: macOS 14+、Swift 5.9+、Xcode コマンドラインツール。

## 🧭 初回起動

アプリ内オンボーディングウィザードが 4 ステップで案内します。

1. **リマインダーへのフルアクセス** — システムダイアログで許可
2. **サブタスク Shortcut の取り込み** — Shortcuts.app に専用ショートカットを追加
3. **フルディスクアクセス** — サブタスクの階層表示用（任意）
4. **AI プロバイダー設定** — 自然言語追加・サブタスク自動生成用（任意）

各ステップは「あとで」スキップ可能。設定は「⋯」メニューからいつでも変更できます。

## 🤖 AI モード

入力欄でモードを `AI` に切替えると、自然言語が解釈されます。

| 入力 | 結果 |
|---|---|
| `明日 15 時に歯医者` | 「歯医者」明日 15:00 |
| `今週金曜までに資料作る` | 「資料作る」今週金曜 |
| `https://example.com の記事を読む` | 「記事を読む」+ URL |
| `家事リストに洗濯と掃除を追加` | 2 件を「家事」リストに |

### プロバイダー

「⋯ → AI 設定」から以下を切替：

| プロバイダー | 必要なもの |
|---|---|
| **Claude Code (CLI)** | `claude` コマンドが PATH に通っていれば即動く |
| **Anthropic API** | [console.anthropic.com](https://console.anthropic.com/) の API キー |
| **OpenAI** | [platform.openai.com](https://platform.openai.com/) の API キー |
| **Google Gemini** | [aistudio.google.com](https://aistudio.google.com/) の API キー |

API キーは macOS Keychain (Generic Password) にのみ保存され、平文ファイルやサーバーには出ません。

### サブタスク自動分解

親タスクを展開して **`✨ AIで生成`** をタップ → AI が 3〜7 件のサブタスクを提案 → 編集・追加・削除して **追加する** で一括登録。

## 🌳 サブタスク機能の仕組み

EventKit にはサブタスク用の公開 API が無いため、Hutch は次の方式で純正アプリと同じ親子関係を扱います：

- **書き込み**: バンドルされた Shortcuts.app の専用ショートカット (`AddSubReminder.shortcut`) を `/usr/bin/shortcuts run` で叩く
- **読み取り**: 純正アプリの SQLite (`~/Library/Group Containers/group.com.apple.reminders/...`) を read-only でスナップショットコピーして親子マップを抽出

詳細は [サブタスクのセットアップ](#-サブタスクのセットアップ) 参照。

## 🎯 進行中ステータス

チェックボックスをタップで 3 状態サイクル：

| 状態 | 表示 | 内部表現 |
|:-:|:-:|---|
| 未着手 | ◯ | `isCompleted = false`、`#wip` 無し |
| 進行中 | スピナー | `isCompleted = false`、`#wip` タグ付与 |
| 完了 | ✓ | `isCompleted = true` |

`#wip` タグは iCloud 同期で iPhone でも見え、純正アプリ上でも編集可能。タグ名は `ReminderStore.swift` の `progressTag` で変更可。

## 🌐 サブタスクのセットアップ

オンボーディングで案内されますが、後から手動で行う手順：

### 1. ショートカットを取り込む

```bash
open ~/Applications/Hutch.app/Contents/Resources/AddSubReminder.shortcut
```

Shortcuts.app の取り込みダイアログで **「ショートカットを追加」** を選択。名前は `ReminderMenu Add Subtask` のまま変更不可（互換性のため）。

### 2. 階層表示にはフルディスクアクセスが必要

```
システム設定 → プライバシーとセキュリティ → フルディスクアクセス → Hutch を ON
```

未許可でもサブタスクは追加できます（フラット表示にフォールバック）。純正アプリ・iPhone では正しく階層表示されます。

### 制限事項

- macOS Shortcuts の「リマインダーを検索」アクションは ID フィルタを持たないため、親はタイトル + リストで特定
- 同一リスト内に未完了の同名リマインダーが複数あるとエラー
- 階層は 1 段のみ対応（純正アプリ仕様に追従）

## 🏗 設計

<details>
<summary>アーキテクチャ図と主要ファイル</summary>

```
┌──────────────────────────────────────────────┐
│              Hutch.app                       │
│  ┌──────────────────────────────────────┐    │
│  │  SwiftUI View Layer                  │    │
│  │  MainView / ReminderRow / Calendar   │    │
│  └────────────┬─────────────────────────┘    │
│               │                              │
│  ┌────────────▼─────────────────────────┐    │
│  │  ReminderStore (ObservableObject)    │    │
│  └────┬──────────┬──────────┬───────────┘    │
│       │          │          │                │
│  ┌────▼───┐ ┌────▼─────┐ ┌──▼──────────┐     │
│  │EventKit│ │Shortcuts │ │ SQLite      │     │
│  │read/   │ │ CLI      │ │ read-only   │     │
│  │write   │ │(subtask) │ │(parent map) │     │
│  └────────┘ └──────────┘ └─────────────┘     │
│                                              │
│  ┌────────────────────────────────────┐      │
│  │  AIProvider (Claude/OpenAI/Gemini) │      │
│  └────────────────────────────────────┘      │
└──────────────────────────────────────────────┘
        │                │              │
        ▼                ▼              ▼
   iCloud Reminders  Shortcuts.app  ~/Library/.../Reminders
```

### 主要ファイル

| ファイル | 役割 |
|---|---|
| `ReminderStore.swift` | EventKit の読み書き、進行中ステータス、サブタスク統合 |
| `RemindersSQLite.swift` | 純正 DB から親子マップ抽出（read-only） |
| `ShortcutsBridge.swift` | `shortcuts run` の Swift ラッパー |
| `AIProvider.swift` + `Providers/*.swift` | LLM プロバイダー抽象と実装 |
| `NLParser.swift` | 自然言語 → `ReminderDraft` / サブタスク候補 |
| `Holidays.swift` | 日本の祝日をルールベース計算 |
| `MainView.swift` | メニューバーポップオーバーのトップ |
| `OnboardingView.swift` | 初回起動ウィザード |

</details>

## 💡 なぜ "Hutch" なのか

Hutch は **作業中の手元に置く、リマインダー専用の小さな棚** です。

純正リマインダーは iCloud 同期も繰り返しもリスト管理も揃っているのに、Mac だと「Cmd+Tab → Reminders → 入力 → 閉じる」の儀式が地味に面倒。机から立って奥の戸棚を開けに行く感覚に近い。書きたい時にサッと書けない。

`hutch`（ハッチ）— キッチンやワークスペースの片隅にある、よく使うものを並べておく **小さな棚**。引き出しの奥にしまわず、目に入って、すぐ手が届く場所に置いておく家具のこと。

その「ハッチ」をメニューバーに置く、というのが Hutch のコンセプト。**データは純正のまま、置き場所だけメニューバー 1 クリックの距離に**。Things や OmniFocus のように別のデータストアへ引っ越す必要はありません。

## 🛠 開発

```bash
# デバッグビルド
swift build

# リリースビルド + ~/Applications にインストール
./scripts/build_app.sh --install

# 再起動
pkill -f Hutch.app && open ~/Applications/Hutch.app
```

外部依存なし（Swift Package Manager のみ、SQLite3 はシステム）。

### リリース手順

```bash
git tag v0.X.Y
git push origin v0.X.Y
```

GitHub Actions が自動で:
1. macOS 14 でビルド
2. `.dmg` 生成 + SHA256 計算
3. GitHub Release 公開
4. Homebrew Cask の version / sha256 を main に自動 push

## 🤝 Contributing

PR / Issue 歓迎。

- バグ報告: [Issue を開く](https://github.com/Riku4230/Hutch/issues/new)
- 機能要望: [Discussions](https://github.com/Riku4230/Hutch/discussions) か Issue
- セキュリティ: [SECURITY.md](SECURITY.md) を参照

## 📄 ライセンス

MIT License — 自由に fork / 改変してください。詳細は [LICENSE](LICENSE) を参照。

## 🙏 クレジット

- 自然言語解釈: [Anthropic Claude](https://www.anthropic.com/) / [OpenAI](https://openai.com/) / [Google Gemini](https://ai.google.dev/)
- アイコン: `Resources/AppIcon.icns`

---

<div align="center">

Made with ❤️ for the macOS Reminders ecosystem

</div>
