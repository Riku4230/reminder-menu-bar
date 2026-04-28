import Foundation

/// メニューバーアイコンの脈動アニメ発火イベント。
///
/// 永続的なバッジ / マークは置かず、「動き」だけで通知を伝える方針。
/// ReminderStore が定期的に 30 秒タイマーで判定し、ヒットしたら PassthroughSubject で
/// 流す。AppDelegate が受けてアイコンに scale + bounce アニメを掛ける。
struct MenuBarPulse: Identifiable, Equatable {
    let id: UUID
    let title: String
    let kind: Kind
    let firedAt: Date

    enum Kind: Equatable {
        /// ユーザーが明示的に立てた EKAlarm 時刻が現在時刻と一致
        case alarm
        /// 時刻指定なしリマインダーのデフォルト 17:00 タイミング
        case dateOnly
        /// 期限切れタスクの再レビュー（毎日 17:00）
        case overdueReview
    }

    init(title: String, kind: Kind, firedAt: Date = Date()) {
        self.id = UUID()
        self.title = title
        self.kind = kind
        self.firedAt = firedAt
    }
}
