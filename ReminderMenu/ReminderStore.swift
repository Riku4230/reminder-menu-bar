import AppKit
import Combine
import EventKit
import SwiftUI

enum SmartList: String, CaseIterable, Identifiable {
    case today
    case scheduled
    case all
    case important

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "今日"
        case .scheduled: return "予定"
        case .all: return "すべて"
        case .important: return "フラグあり"
        }
    }

    var symbolName: String {
        switch self {
        case .today: return "smallcircle.filled.circle"
        case .scheduled: return "calendar"
        case .all: return "tray"
        case .important: return "flag"
        }
    }

    var color: Color {
        switch self {
        case .today: return MRTheme.accent
        case .scheduled: return MRTheme.blue
        case .all: return MRTheme.gray
        case .important: return MRTheme.red
        }
    }
}

enum RecurrenceFrequency: String, CaseIterable, Identifiable {
    case none, daily, weekly, monthly, yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "しない"
        case .daily: return "毎日"
        case .weekly: return "毎週"
        case .monthly: return "毎月"
        case .yearly: return "毎年"
        }
    }

    var symbolName: String {
        switch self {
        case .none: return "minus.circle"
        default: return "arrow.triangle.2.circlepath"
        }
    }
}

enum EarlyReminderChoice: String, CaseIterable, Identifiable {
    case none, atTime, fiveMin, fifteenMin, thirtyMin, oneHour, oneDay

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "なし"
        case .atTime: return "予定時刻"
        case .fiveMin: return "5分前"
        case .fifteenMin: return "15分前"
        case .thirtyMin: return "30分前"
        case .oneHour: return "1時間前"
        case .oneDay: return "1日前"
        }
    }

    var shortLabel: String {
        switch self {
        case .none: return "通知"
        case .atTime: return "予定時刻"
        case .fiveMin: return "5分前"
        case .fifteenMin: return "15分前"
        case .thirtyMin: return "30分前"
        case .oneHour: return "1時間前"
        case .oneDay: return "1日前"
        }
    }

    var offsetSeconds: TimeInterval {
        switch self {
        case .none: return 0
        case .atTime: return 0
        case .fiveMin: return -5 * 60
        case .fifteenMin: return -15 * 60
        case .thirtyMin: return -30 * 60
        case .oneHour: return -60 * 60
        case .oneDay: return -24 * 60 * 60
        }
    }
}

enum SortMode: String, CaseIterable, Identifiable {
    case dueDate
    case priority
    case title

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dueDate: return "期限順"
        case .priority: return "優先度順"
        case .title: return "タイトル順"
        }
    }
}

/// 「未着手 / 進行中 / 完了」の 3 値ステータス。
/// EventKit は完了状態しか持たないため、進行中は `#wip` タグの有無で擬似表現する。
enum ProgressState {
    case notStarted
    case inProgress
    case completed
}

enum ReminderSelection: Hashable {
    case smart(SmartList)
    case calendar(String)
}

struct ReminderCalendar: Identifiable, Hashable {
    let id: String
    let title: String
    let color: Color
    let nsColor: NSColor
    let sourceTitle: String
    let count: Int
}

struct ReminderGroup: Identifiable {
    let id: String
    let title: String?
    let color: Color
    let reminders: [EKReminder]
}

/// 親子関係を表す描画用のノード。同じリマインダーが複数 depth で表示される可能性は無いので
/// id は EKReminder.calendarItemIdentifier をそのまま使う。
struct ReminderTreeNode: Identifiable {
    let reminder: EKReminder
    let depth: Int
    var id: String { reminder.calendarItemIdentifier }
}

struct ReminderDraft: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var dueDate: Date?
    var includesTime: Bool
    var priority: Int
    var listName: String?

    init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date? = nil,
        includesTime: Bool = false,
        priority: Int = 0,
        listName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.includesTime = includesTime
        self.priority = priority
        self.listName = listName
    }
}

@MainActor
final class ReminderStore: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    @Published private(set) var calendars: [ReminderCalendar] = []
    @Published private(set) var reminders: [EKReminder] = []
    @Published var selection: ReminderSelection = .smart(.today)
    @Published var searchText = ""
    @Published var showCompleted = false {
        didSet { reloadReminders() }
    }
    @Published var sortMode: SortMode = .dueDate
    @Published var lastError: String?

    /// child reminder identifier → parent reminder identifier。
    /// SQLite から復元される。FDA 未許可など読めない場合は空のまま。
    @Published private(set) var parentMap: [String: String] = [:]
    /// 親子マップ取得が成功したかどうか。false の時は階層表示が無効化される。
    @Published private(set) var hasFullDiskAccess: Bool = true

    /// 進行中ステータスを表すタグ名（先頭の `#` は含めない）
    static let progressTag = "wip"

    private var childMap: [String: [String]] = [:]   // parentID -> [childID]

    private let eventStore = EKEventStore()
    private var activeFetch: Any?
    private let calendar = Calendar.current

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(eventStoreChanged),
            name: .EKEventStoreChanged,
            object: eventStore
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var hasFullAccess: Bool {
        authorizationStatus == .fullAccess
    }

    var selectedSmartList: SmartList? {
        if case let .smart(list) = selection { return list }
        return nil
    }

    var displayTitle: String {
        switch selection {
        case .smart(let list):
            return list.title
        case .calendar(let id):
            return calendars.first(where: { $0.id == id })?.title ?? "リスト"
        }
    }

    var displaySubtitle: String {
        let count = filteredReminders.count
        if selectedSmartList == .today {
            return "\(count) 件 · \(DateFormatter.monthDay.string(from: Date()))"
        }
        return "\(count) 件"
    }

    var selectedColor: Color {
        switch selection {
        case .smart(let list):
            return list.color
        case .calendar(let id):
            return calendars.first(where: { $0.id == id })?.color ?? MRTheme.accent
        }
    }

    var smartListIconName: String {
        switch selection {
        case .smart(let list): return list.symbolName
        case .calendar: return "list.bullet"
        }
    }

    var selectedCalendarIDForCreation: String? {
        if case let .calendar(id) = selection { return id }
        return nil
    }

    var filteredReminders: [EKReminder] {
        let selected = reminders.filter { reminder in
            switch selection {
            case .smart(let smart):
                return matches(reminder: reminder, smartList: smart)
            case .calendar(let id):
                return reminder.calendar.calendarIdentifier == id
            }
        }

        let searched: [EKReminder]
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searched = selected
        } else {
            let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            searched = selected.filter {
                $0.title.localizedCaseInsensitiveContains(needle)
                    || ($0.notes?.localizedCaseInsensitiveContains(needle) ?? false)
            }
        }

        return searched.sorted(by: reminderSort)
    }

    var groupedReminders: [ReminderGroup] {
        let current = filteredReminders
        guard case .smart(let smart) = selection, smart == .all || smart == .scheduled else {
            return [
                ReminderGroup(
                    id: "single",
                    title: nil,
                    color: selectedColor,
                    reminders: current
                )
            ]
        }

        let grouped = Dictionary(grouping: current) { $0.calendar.calendarIdentifier }
        return grouped.keys.sorted { lhs, rhs in
            let lt = calendarTitle(for: lhs)
            let rt = calendarTitle(for: rhs)
            return lt.localizedStandardCompare(rt) == .orderedAscending
        }
        .compactMap { id in
            guard let items = grouped[id], let first = items.first else { return nil }
            return ReminderGroup(
                id: id,
                title: first.calendar.title,
                color: color(for: first.calendar),
                reminders: items
            )
        }
    }

    func requestAccessAndLoad() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
        switch authorizationStatus {
        case .fullAccess:
            reloadAll()
        case .notDetermined:
            eventStore.requestFullAccessToReminders { [weak self] granted, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
                    if let error {
                        self.lastError = error.localizedDescription
                    }
                    if granted {
                        self.reloadAll()
                    }
                }
            }
        case .denied, .restricted, .writeOnly:
            reminders = []
            calendars = []
        @unknown default:
            reminders = []
            calendars = []
        }
    }

    func reloadAll() {
        loadCalendars()
        reloadReminders()
    }

    func reloadReminders() {
        guard hasFullAccess else { return }
        if let activeFetch {
            eventStore.cancelFetchRequest(activeFetch)
            self.activeFetch = nil
        }

        let predicate: NSPredicate
        if showCompleted {
            predicate = eventStore.predicateForReminders(in: nil)
        } else {
            predicate = eventStore.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: nil,
                calendars: nil
            )
        }

        activeFetch = eventStore.fetchReminders(matching: predicate) { [weak self] fetched in
            DispatchQueue.main.async {
                guard let self else { return }
                self.reminders = fetched ?? []
                self.loadCalendars()
                self.refreshParentMap()
            }
        }
    }

    /// SQLite から親子マップを再構築。FDA 未許可は静かに失敗してフラット表示にフォールバック。
    private func refreshParentMap() {
        do {
            let map = try RemindersSQLite.loadParentMap()
            self.parentMap = map
            self.childMap = Dictionary(grouping: map, by: { $0.value })
                .mapValues { $0.map(\.key) }
            self.hasFullDiskAccess = true
        } catch RemindersSQLite.AccessError.permissionDenied {
            self.parentMap = [:]
            self.childMap = [:]
            self.hasFullDiskAccess = false
        } catch {
            // DB 不在やスキーマ差異は無視（フラット表示にフォールバック）
            self.parentMap = [:]
            self.childMap = [:]
        }
    }

    // MARK: - Subtasks

    /// 指定リマインダーのサブタスク（取得済み reminders から該当する子を返す）
    func subtasks(of reminder: EKReminder) -> [EKReminder] {
        let key = reminder.calendarItemIdentifier
        guard let childIDs = childMap[key], !childIDs.isEmpty else { return [] }
        let lookup = Dictionary(uniqueKeysWithValues: reminders.map { ($0.calendarItemIdentifier, $0) })
        return childIDs.compactMap { lookup[$0] }
    }

    /// 指定リマインダーが他リマインダーのサブタスクなら親 EKReminder を返す
    func parent(of reminder: EKReminder) -> EKReminder? {
        guard let parentID = parentMap[reminder.calendarItemIdentifier] else { return nil }
        return reminders.first { $0.calendarItemIdentifier == parentID }
    }

    func isSubtask(_ reminder: EKReminder) -> Bool {
        parentMap[reminder.calendarItemIdentifier] != nil
    }

    /// Shortcuts.app 経由でサブタスクを追加。
    /// EventKit に書き込み API が無いため `/usr/bin/shortcuts run` を呼び出す。
    func addSubtask(under parent: EKReminder, title: String) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try await ShortcutsBridge.addSubtask(
            parentID: parent.calendarItemIdentifier,
            title: trimmed,
            listName: parent.calendar.title
        )
        // EKEventStoreChanged で勝手にリロードされるはずだが、Shortcuts 経由は通知が遅れることがあるので保険
        try? await Task.sleep(nanoseconds: 400_000_000)
        reloadReminders()
    }

    // MARK: - Progress State (in-progress via #wip tag)

    /// 「未着手 / 進行中 / 完了」の 3 値を返す
    func progressState(of reminder: EKReminder) -> ProgressState {
        if reminder.isCompleted { return .completed }
        return tags(for: reminder).contains(Self.progressTag) ? .inProgress : .notStarted
    }

    /// 状態を直接セット。完了時は `#wip` を外し、進行中時は付与する。
    func setProgressState(_ state: ProgressState, for reminder: EKReminder) {
        switch state {
        case .notStarted:
            removeWipSilently(reminder)
            if reminder.isCompleted { reminder.isCompleted = false }
            save(reminder)
        case .inProgress:
            if reminder.isCompleted { reminder.isCompleted = false }
            if !tags(for: reminder).contains(Self.progressTag) {
                addTag(Self.progressTag, to: reminder)
                return // addTag が save までやる
            }
            save(reminder)
        case .completed:
            removeWipSilently(reminder)
            if !reminder.isCompleted {
                reminder.isCompleted = true
                reminder.completionDate = Date()
            }
            save(reminder)
        }
    }

    /// 状態を 未着手 → 進行中 → 完了 → 未着手 の順でサイクル。
    func cycleProgressState(_ reminder: EKReminder) {
        let next: ProgressState
        switch progressState(of: reminder) {
        case .notStarted: next = .inProgress
        case .inProgress: next = .completed
        case .completed: next = .notStarted
        }
        setProgressState(next, for: reminder)
    }

    /// `#wip` タグだけを取り除く（save は呼ばない）。複数の状態変更を 1 セーブにまとめるため。
    private func removeWipSilently(_ reminder: EKReminder) {
        let remaining = tags(for: reminder).filter { $0 != Self.progressTag }
        reminder.notes = composeNotes(memo: memo(for: reminder), tags: remaining)
    }

    /// メタ表示用のタグ一覧。`#wip` はチェックボックスで表現するためタグチップからは除外する。
    func displayTags(for reminder: EKReminder) -> [String] {
        tags(for: reminder).filter { $0 != Self.progressTag }
    }

    func count(for smartList: SmartList) -> Int {
        reminders.filter { matches(reminder: $0, smartList: smartList) }.count
    }

    func toggleCompleted(_ reminder: EKReminder) {
        reminder.isCompleted.toggle()
        save(reminder)
    }

    func cyclePriority(_ reminder: EKReminder) {
        switch reminder.priority {
        case 0: reminder.priority = 1
        case 1...4: reminder.priority = 5
        case 5: reminder.priority = 9
        default: reminder.priority = 0
        }
        save(reminder)
    }

    func setPriority(_ reminder: EKReminder, to priority: Int) {
        reminder.priority = normalizedPriority(priority)
        save(reminder)
    }

    func updateReminder(_ reminder: EKReminder, title: String, dueDate: Date?, includesTime: Bool) {
        reminder.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.dueDateComponents = dateComponents(for: dueDate, includesTime: includesTime)
        save(reminder)
    }

    // MARK: - Notes / Memo / Tags / URL / Flag

    private static let tagPattern: NSRegularExpression = {
        // #tag — supports JP, alphanumerics, underscore, hyphen
        return try! NSRegularExpression(pattern: #"(?:^|\s)#([\p{L}\p{N}_-]+)"#)
    }()

    func notes(for reminder: EKReminder) -> String {
        reminder.notes ?? ""
    }

    func memo(for reminder: EKReminder) -> String {
        let raw = reminder.notes ?? ""
        let range = NSRange(raw.startIndex..., in: raw)
        let stripped = Self.tagPattern.stringByReplacingMatches(in: raw, range: range, withTemplate: "")
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func tags(for reminder: EKReminder) -> [String] {
        let raw = reminder.notes ?? ""
        let range = NSRange(raw.startIndex..., in: raw)
        let matches = Self.tagPattern.matches(in: raw, range: range)
        let names = matches.compactMap { match -> String? in
            guard let r = Range(match.range(at: 1), in: raw) else { return nil }
            return String(raw[r])
        }
        // Deduplicate while preserving order
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }

    func setMemo(_ reminder: EKReminder, memo: String) {
        let trimmed = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingTags = tags(for: reminder)
        reminder.notes = composeNotes(memo: trimmed, tags: existingTags)
        save(reminder)
    }

    func addTag(_ tag: String, to reminder: EKReminder) {
        let cleaned = sanitizeTag(tag)
        guard !cleaned.isEmpty else { return }
        var current = tags(for: reminder)
        guard !current.contains(cleaned) else { return }
        current.append(cleaned)
        reminder.notes = composeNotes(memo: memo(for: reminder), tags: current)
        save(reminder)
    }

    func removeTag(_ tag: String, from reminder: EKReminder) {
        let current = tags(for: reminder).filter { $0 != tag }
        reminder.notes = composeNotes(memo: memo(for: reminder), tags: current)
        save(reminder)
    }

    func setURL(_ reminder: EKReminder, url: URL?) {
        reminder.url = url
        save(reminder)
    }

    // MARK: - Recurrence

    func recurrenceFrequency(for reminder: EKReminder) -> RecurrenceFrequency {
        guard let rule = reminder.recurrenceRules?.first else { return .none }
        switch rule.frequency {
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .yearly: return .yearly
        @unknown default: return .none
        }
    }

    // MARK: - Early reminder (EKAlarm relativeOffset)

    func earlyReminderChoice(for reminder: EKReminder) -> EarlyReminderChoice {
        guard let alarms = reminder.alarms, !alarms.isEmpty else { return .none }
        let offset = alarms.first?.relativeOffset ?? 0
        if offset == 0 { return .atTime }
        let mins = Int(abs(offset) / 60)
        if mins == 5 { return .fiveMin }
        if mins == 15 { return .fifteenMin }
        if mins == 30 { return .thirtyMin }
        if mins == 60 { return .oneHour }
        if mins == 24 * 60 { return .oneDay }
        return .none
    }

    func setEarlyReminder(_ reminder: EKReminder, choice: EarlyReminderChoice) {
        if let alarms = reminder.alarms {
            for alarm in alarms { reminder.removeAlarm(alarm) }
        }
        if choice != .none {
            let alarm = EKAlarm(relativeOffset: choice.offsetSeconds)
            reminder.addAlarm(alarm)
        }
        save(reminder)
    }

    func setRecurrence(_ reminder: EKReminder, frequency: RecurrenceFrequency) {
        if frequency == .none {
            reminder.recurrenceRules = nil
        } else {
            let ekFreq: EKRecurrenceFrequency
            switch frequency {
            case .daily: ekFreq = .daily
            case .weekly: ekFreq = .weekly
            case .monthly: ekFreq = .monthly
            case .yearly: ekFreq = .yearly
            case .none: return
            }
            let rule = EKRecurrenceRule(recurrenceWith: ekFreq, interval: 1, end: nil)
            reminder.recurrenceRules = [rule]
        }
        save(reminder)
    }

    private func composeNotes(memo: String, tags: [String]) -> String? {
        var components: [String] = []
        if !memo.isEmpty { components.append(memo) }
        if !tags.isEmpty {
            components.append(tags.map { "#\($0)" }.joined(separator: " "))
        }
        let result = components.joined(separator: "\n\n")
        return result.isEmpty ? nil : result
    }

    private func sanitizeTag(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutHash = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        return withoutHash.replacingOccurrences(of: " ", with: "_")
    }

    // MARK: - Flag (UserDefaults-backed since EventKit has no flagged property)

    private static let flaggedKey = "ReminderMenu.flagged"

    private func reminderKey(_ reminder: EKReminder) -> String {
        reminder.calendarItemExternalIdentifier ?? reminder.calendarItemIdentifier
    }

    func isFlagged(_ reminder: EKReminder) -> Bool {
        let flagged = UserDefaults.standard.stringArray(forKey: Self.flaggedKey) ?? []
        return flagged.contains(reminderKey(reminder))
    }

    func toggleFlagged(_ reminder: EKReminder) {
        var flagged = UserDefaults.standard.stringArray(forKey: Self.flaggedKey) ?? []
        let key = reminderKey(reminder)
        if let i = flagged.firstIndex(of: key) {
            flagged.remove(at: i)
        } else {
            flagged.append(key)
        }
        UserDefaults.standard.set(flagged, forKey: Self.flaggedKey)
        objectWillChange.send()
    }

    func removeReminder(_ reminder: EKReminder) {
        do {
            try eventStore.remove(reminder, commit: true)
            reloadReminders()
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func addReminder(
        title: String,
        dueDate: Date?,
        includesTime: Bool,
        priority: Int,
        calendarID: String?,
        listName: String? = nil
    ) throws -> EKReminder {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            throw NSError(domain: "ReminderMenu", code: 1, userInfo: [NSLocalizedDescriptionKey: "タイトルが空です"])
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = cleanTitle
        reminder.priority = normalizedPriority(priority)
        reminder.calendar = resolveCalendar(calendarID: calendarID, listName: listName)
        reminder.dueDateComponents = dateComponents(for: dueDate, includesTime: includesTime)
        try eventStore.save(reminder, commit: true)
        reloadReminders()
        return reminder
    }

    func addDrafts(_ drafts: [ReminderDraft], fallbackCalendarID: String?) throws -> [String] {
        var titles: [String] = []
        for draft in drafts {
            let reminder = EKReminder(eventStore: eventStore)
            reminder.title = draft.title
            reminder.priority = normalizedPriority(draft.priority)
            reminder.calendar = resolveCalendar(calendarID: fallbackCalendarID, listName: draft.listName)
            reminder.dueDateComponents = dateComponents(for: draft.dueDate, includesTime: draft.includesTime)
            try eventStore.save(reminder, commit: false)
            titles.append(draft.title)
        }
        try eventStore.commit()
        reloadReminders()
        return titles
    }

    func createList(name: String, color: Color) throws -> String {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            throw NSError(domain: "ReminderMenu", code: 2, userInfo: [NSLocalizedDescriptionKey: "リスト名が空です"])
        }

        let newCalendar = EKCalendar(for: .reminder, eventStore: eventStore)
        newCalendar.title = cleanName
        newCalendar.cgColor = MRTheme.nsColor(for: color).cgColor
        if let source = eventStore.defaultCalendarForNewReminders()?.source ?? preferredReminderSource() {
            newCalendar.source = source
        }
        try eventStore.saveCalendar(newCalendar, commit: true)
        reloadAll()
        return newCalendar.calendarIdentifier
    }

    func moveReminder(identifier: String, toCalendarID calendarID: String) {
        guard let reminder = reminders.first(where: { $0.calendarItemIdentifier == identifier }) else { return }
        guard let target = eventStore.calendar(withIdentifier: calendarID) else { return }
        guard reminder.calendar.calendarIdentifier != calendarID else { return }
        reminder.calendar = target
        save(reminder)
    }

    func updateList(id: String, name: String, color: Color) throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            throw NSError(domain: "ReminderMenu", code: 3, userInfo: [NSLocalizedDescriptionKey: "リスト名が空です"])
        }
        guard let cal = eventStore.calendar(withIdentifier: id) else {
            throw NSError(domain: "ReminderMenu", code: 4, userInfo: [NSLocalizedDescriptionKey: "リストが見つかりません"])
        }
        cal.title = cleanName
        cal.cgColor = MRTheme.nsColor(for: color).cgColor
        try eventStore.saveCalendar(cal, commit: true)
        reloadAll()
    }

    func deleteList(id: String) throws {
        guard let cal = eventStore.calendar(withIdentifier: id) else {
            throw NSError(domain: "ReminderMenu", code: 4, userInfo: [NSLocalizedDescriptionKey: "リストが見つかりません"])
        }
        guard !cal.isImmutable else {
            throw NSError(domain: "ReminderMenu", code: 5, userInfo: [NSLocalizedDescriptionKey: "このリストは削除できません"])
        }
        try eventStore.removeCalendar(cal, commit: true)
        reloadAll()
    }

    func deleteCompleted() {
        guard hasFullAccess else { return }
        let predicate = eventStore.predicateForCompletedReminders(
            withCompletionDateStarting: nil,
            ending: nil,
            calendars: nil
        )
        _ = eventStore.fetchReminders(matching: predicate) { [weak self] fetched in
            DispatchQueue.main.async {
                guard let self else { return }
                do {
                    for reminder in fetched ?? [] {
                        try self.eventStore.remove(reminder, commit: false)
                    }
                    try self.eventStore.commit()
                    self.reloadReminders()
                } catch {
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    func dueDate(for reminder: EKReminder) -> Date? {
        guard var components = reminder.dueDateComponents else { return nil }
        components.calendar = components.calendar ?? calendar
        return components.date
    }

    func includesTime(_ reminder: EKReminder) -> Bool {
        guard let components = reminder.dueDateComponents else { return false }
        return components.hour != nil || components.minute != nil
    }

    func dueLabel(for reminder: EKReminder) -> String? {
        guard let date = dueDate(for: reminder) else { return nil }
        let isToday = calendar.isDateInToday(date)
        let isTomorrow = calendar.isDateInTomorrow(date)
        let time = includesTime(reminder) ? " \(DateFormatter.timeOnly.string(from: date))" : ""

        if isToday { return "今日" + time }
        if isTomorrow { return "明日" + time }
        if includesTime(reminder) { return DateFormatter.dayAndTime.string(from: date) }
        return DateFormatter.monthDay.string(from: date)
    }

    func priorityLabel(for reminder: EKReminder) -> String? {
        switch reminder.priority {
        case 1...4: return "高"
        case 5: return "中"
        case 6...9: return "低"
        default: return nil
        }
    }

    func priorityColor(for reminder: EKReminder) -> Color {
        switch reminder.priority {
        case 1...4: return MRTheme.red
        case 5: return MRTheme.yellow
        case 6...9: return MRTheme.blue
        default: return .secondaryText
        }
    }

    func color(for calendar: EKCalendar) -> Color {
        Color(nsColor: NSColor(cgColor: calendar.cgColor) ?? .systemOrange)
    }

    func calendarTitle(for id: String) -> String {
        calendars.first(where: { $0.id == id })?.title ?? "リスト"
    }

    func openRemindersApp() {
        let url = URL(fileURLWithPath: "/System/Applications/Reminders.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func loadCalendars() {
        guard hasFullAccess else { return }
        let counts = Dictionary(grouping: reminders) { $0.calendar.calendarIdentifier }
            .mapValues(\.count)
        calendars = eventStore.calendars(for: .reminder)
            .map {
                ReminderCalendar(
                    id: $0.calendarIdentifier,
                    title: $0.title,
                    color: color(for: $0),
                    nsColor: NSColor(cgColor: $0.cgColor) ?? .systemOrange,
                    sourceTitle: $0.source.title,
                    count: counts[$0.calendarIdentifier] ?? 0
                )
            }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func matches(reminder: EKReminder, smartList: SmartList) -> Bool {
        switch smartList {
        case .today:
            guard let due = dueDate(for: reminder) else { return false }
            return calendar.isDateInToday(due)
        case .scheduled:
            return dueDate(for: reminder) != nil
        case .all:
            return true
        case .important:
            return isFlagged(reminder)
        }
    }

    private func reminderSort(_ lhs: EKReminder, _ rhs: EKReminder) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted && rhs.isCompleted
        }

        switch sortMode {
        case .dueDate:
            let left = dueDate(for: lhs)
            let right = dueDate(for: rhs)
            if left != right {
                if left == nil { return false }
                if right == nil { return true }
                return left! < right!
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        case .priority:
            let lp = priorityRank(lhs.priority)
            let rp = priorityRank(rhs.priority)
            if lp != rp { return lp < rp }
            return reminderSortByDateThenTitle(lhs, rhs)
        case .title:
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private func reminderSortByDateThenTitle(_ lhs: EKReminder, _ rhs: EKReminder) -> Bool {
        let left = dueDate(for: lhs)
        let right = dueDate(for: rhs)
        if left != right {
            if left == nil { return false }
            if right == nil { return true }
            return left! < right!
        }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    private func priorityRank(_ priority: Int) -> Int {
        switch priority {
        case 1...4: return 0
        case 5: return 1
        case 6...9: return 2
        default: return 3
        }
    }

    private func normalizedPriority(_ priority: Int) -> Int {
        switch priority {
        case 1...4: return 1
        case 5: return 5
        case 6...9: return 9
        default: return 0
        }
    }

    private func save(_ reminder: EKReminder) {
        do {
            try eventStore.save(reminder, commit: true)
            reloadReminders()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func dateComponents(for date: Date?, includesTime: Bool) -> DateComponents? {
        guard let date else { return nil }
        var units: Set<Calendar.Component> = [.year, .month, .day]
        if includesTime {
            units.formUnion([.hour, .minute])
        }
        var components = calendar.dateComponents(units, from: date)
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        if !includesTime {
            components.hour = nil
            components.minute = nil
            components.second = nil
        }
        return components
    }

    private func resolveCalendar(calendarID: String?, listName: String?) -> EKCalendar {
        if let listName, let matched = calendar(named: listName) {
            return matched
        }
        if let calendarID, let calendar = eventStore.calendar(withIdentifier: calendarID) {
            return calendar
        }
        if let defaultCalendar = eventStore.defaultCalendarForNewReminders() {
            return defaultCalendar
        }
        if let first = eventStore.calendars(for: .reminder).first {
            return first
        }
        preconditionFailure("No reminder calendar is available")
    }

    private func calendar(named listName: String) -> EKCalendar? {
        let target = normalizedListName(listName)
        return eventStore.calendars(for: .reminder).first { calendar in
            let title = normalizedListName(calendar.title)
            return title == target || title.contains(target) || target.contains(title)
        }
    }

    private func normalizedListName(_ name: String) -> String {
        name.replacingOccurrences(of: "リスト", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func preferredReminderSource() -> EKSource? {
        eventStore.sources.first { $0.sourceType == .calDAV && $0.title.localizedCaseInsensitiveContains("iCloud") }
            ?? eventStore.sources.first { $0.sourceType == .calDAV }
            ?? eventStore.sources.first
    }

    @objc private func eventStoreChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.reloadAll()
        }
    }
}
