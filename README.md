# Nudge

> macOS のメニューバーから純正 Apple リマインダーをすばやく操作する、AI 搭載の常駐アプリ。

EventKit で純正リマインダーを読み書きするので、書いたタスクは iCloud 経由で iPhone / iPad / Mac の純正アプリにそのまま同期されます。Nudge を消しても、データは純正リマインダー.app に残ります。

## 特徴

- **メニューバー常駐 / Dock 非表示** — `Fn` ダブルタップ or 任意のグローバルショートカットで開閉
- **Glass Float デザイン** — ライト / ダーク / システム追従の外観切替
- **3 状態チェックボックス** — 未着手 / 進行中 / 完了（進行中は `#wip` タグで iCloud 同期）
- **サブタスクの追加・階層表示** — Shortcuts.app + SQLite 直読で純正アプリと同じ親子関係を扱える
- **AI モード（マルチプロバイダー対応）** — Claude Code CLI / Anthropic API / OpenAI / Gemini から選択可能
  - 自然言語からのリマインダー追加（「明日 15 時に歯医者 https://...」→ 期日 / メモ / URL を抽出）
  - 親タスクをサブタスクに自動分解（`✨ AIで生成` ボタン）
- **カレンダービュー** — 月グリッドにリマインダーをリスト色のドットで表示、日本の祝日に対応
- **スマートリスト** — 今日 / 予定 / すべて / フラグあり
- **iCloud 共有リスト対応** — 純正アプリで作ったリストはそのまま使える

## インストール

### ビルド

要件: macOS 14 以降、Swift 5.9 以降、Xcode コマンドラインツール。

```bash
git clone https://github.com/Riku4230/Nudge.git
cd Nudge
./scripts/build_app.sh --install
```

`~/Applications/Nudge.app` にインストールされるので、`open ~/Applications/Nudge.app` か Spotlight で起動してください。

`--install` を付けない場合は `build/Nudge.app` に生成されます。

### 初回起動時

1. **リマインダーへのフルアクセス** — ダイアログが出るので「許可」
2. **サブタスク機能** — メニュー右上の「⋯」から有効化（任意、後述）
3. **AI モード** — 同じく「⋯」→ AI 設定でプロバイダーと API キーを設定（任意）

## サブタスク機能のセットアップ

EventKit にはサブタスクの公開 API が無いため、Nudge は Shortcuts.app の「リマインダーを追加」アクション経由でサブタスクを書き込みます。アプリにバンドルされたショートカットを 1 度だけ取り込んでください。

### 1. ショートカットを取り込む

`~/Applications/Nudge.app/Contents/Resources/AddSubReminder.shortcut` をダブルクリックすると Shortcuts.app の取り込みダイアログが開きます。**「ショートカットを追加」** を選択してください。

> アプリ内からも「⋯ → サブタスクを有効化」で同じファイルを開けます。

ショートカットの名前は **`ReminderMenu Add Subtask`** のまま変更しないでください（Nudge から CLI で呼び出すための識別子です）。

### 2. 階層表示（読み取り）の権限

サブタスクの**追加**は上記だけで動きますが、**階層表示**（メニュー内で親 → 子をインデント表示）には純正リマインダー.app の SQLite を読む必要があり、**フルディスクアクセス** の許可が必要です：

```
システム設定 → プライバシーとセキュリティ → フルディスクアクセス → Nudge を ON
```

未許可でもサブタスク自体は動作します。Nudge 内ではフラットに表示されますが、純正アプリ・iPhone では正しく階層表示されます。

### 制限事項

- macOS Shortcuts の「リマインダーを検索」アクションは ID フィルタを持たないため、親はタイトル + リストで特定します
- 同一リスト内に未完了の同名リマインダーが複数あると、Nudge 側で `addSubtask` 呼び出し時にエラーを返します（誤った親への紐付けを防ぐため）
- 階層は 1 段のみ対応（純正アプリの UI と同じ仕様）

## AI モード

メニュー下部の入力欄で「AI」モードを選択すると自然言語入力が解釈されます。

| 入力例 | 解釈結果 |
|---|---|
| `明日 15 時に歯医者` | タイトル「歯医者」、明日 15:00 |
| `今週金曜までに資料作る` | タイトル「資料作る」、今週金曜 |
| `https://example.com の記事を読む` | タイトル「記事を読む」、URL セット |
| `家事リストに洗濯と掃除を追加` | 2 件（洗濯 / 掃除）を「家事」リストへ |

### プロバイダー設定

「⋯ → AI 設定」から以下のいずれかを選択：

| プロバイダー | 必要なもの |
|---|---|
| **Claude Code (CLI)** | `claude` コマンドが PATH に通っていること |
| **Anthropic API** | `https://console.anthropic.com/` の API キー |
| **OpenAI** | `https://platform.openai.com/` の API キー |
| **Google Gemini** | `https://aistudio.google.com/` の API キー |

API キーは Keychain (Generic Password) に保存されます。

### サブタスク自動生成

親タスクを展開して `✨ AIで生成` を押すと、AI が 3〜7 件のサブタスクを提案します。確認ポップオーバーで編集・削除・追加してから一括登録できます。

## 進行中ステータス

チェックボックスをタップすると 3 状態をサイクルします：

| 状態 | 表示 | 内部表現 |
|---|---|---|
| 未着手 | 空の円 | `isCompleted = false` / `#wip` なし |
| 進行中 | アクセント色のスピナー | `isCompleted = false` / `#wip` タグあり |
| 完了 | 塗りつぶし + チェック | `isCompleted = true` |

`#wip` タグは純正リマインダー.app・iPhone でもタグとして見え、iCloud 同期されます。タグ名は `ReminderMenu/ReminderStore.swift` の `progressTag` 定数で変更可能です。

## アーキテクチャ

```
┌──────────────────────────────────────────────┐
│              Nudge.app                       │
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
│  │write   │ │(subtask  │ │(parent map) │     │
│  │        │ │ create)  │ │             │     │
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

### 主要なファイル

| ファイル | 役割 |
|---|---|
| `ReminderStore.swift` | EventKit の読み書き、進行中ステータス管理、サブタスク統合 |
| `RemindersSQLite.swift` | 純正アプリの SQLite から親子マップを読む |
| `ShortcutsBridge.swift` | `/usr/bin/shortcuts run` の Swift ラッパー |
| `AIProvider.swift` | LLM プロバイダー抽象（Claude/OpenAI/Gemini を統一） |
| `Providers/*.swift` | 各 LLM の実装 |
| `NLParser.swift` | 自然言語 → ReminderDraft / サブタスク候補 |
| `Holidays.swift` | 日本の祝日をルールベース計算 |
| `MainView.swift` | メニューバーポップオーバーのトップビュー |
| `ReminderRow.swift` | 個別リマインダー行（編集 UI 付き） |
| `CalendarView.swift` | 月カレンダービュー |

## なぜ作ったか

純正リマインダーは iCloud 同期や iOS との連携が強いが、Mac での「サクッと開いて書き込んで閉じる」が弱い。Things や OmniFocus は別データストアで、結局純正アプリに残っているタスクと混ざらない。

Nudge は **純正のデータをそのまま使いつつ**、Mac で快適にタスクを足せる UI を被せる、という路線で作っています。

## 開発

```bash
# デバッグビルド
swift build

# 実機で動かす（リリースビルド + ~/Applications にインストール）
./scripts/build_app.sh --install

# 起動中のプロセスを kill して再起動
pkill -f Nudge.app && open ~/Applications/Nudge.app
```

依存ライブラリ無し（SwiftPM だけ、SQLite3 はシステム）。Swift Package Manager のみでビルドできます。

## ライセンス

MIT License — 自由に fork / 改変してください。

## クレジット

- アイコン: `Resources/AppIcon.icns`
- 自然言語解釈: Anthropic Claude / OpenAI GPT / Google Gemini
