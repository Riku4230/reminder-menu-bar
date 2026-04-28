import AppKit
import Foundation
import SwiftUI

/// アプリ内（popover を開いている時）のキーボードショートカット定義。
///
/// グローバルホットキー（メニューバーから popover を開くもの）とは別管理。
/// MVP では keybinding は固定だが、将来カスタマイズ可能にするための設計を残す。
/// `displayLabel` だけ提示して、ユーザーは設定シートで一覧を確認できる。
enum AppShortcutAction: String, CaseIterable, Identifiable {
    case focusInput
    case focusSearch
    case toggleInputMode
    case smartListToday
    case smartListScheduled
    case smartListAll
    case smartListImportant
    case closePopover

    var id: String { rawValue }

    /// 設定シートで表示するアクション名
    var label: String {
        switch self {
        case .focusInput:        return "入力欄にフォーカス"
        case .focusSearch:       return "検索にフォーカス"
        case .toggleInputMode:   return "通常 / AI モード切替"
        case .smartListToday:    return "スマートリスト: 今日"
        case .smartListScheduled:return "スマートリスト: 予定"
        case .smartListAll:      return "スマートリスト: すべて"
        case .smartListImportant:return "スマートリスト: フラグあり"
        case .closePopover:      return "ポップオーバーを閉じる"
        }
    }

    /// 設定シートで表示する人間向けの key 表記
    var displayShortcut: String {
        switch self {
        case .focusInput:        return "⌘N"
        case .focusSearch:       return "⌘F"
        case .toggleInputMode:   return "⌘ /"
        case .smartListToday:    return "⌘1"
        case .smartListScheduled:return "⌘2"
        case .smartListAll:      return "⌘3"
        case .smartListImportant:return "⌘4"
        case .closePopover:      return "⎋"
        }
    }

    /// 並び順（設定シート用）
    static var displayOrder: [AppShortcutAction] {
        [
            .focusInput, .focusSearch, .toggleInputMode,
            .smartListToday, .smartListScheduled, .smartListAll, .smartListImportant,
            .closePopover
        ]
    }
}
