import EventKit
import SwiftUI

/// 月カレンダー + 選択日のリマインダー + 期日なしセクションを表示するビュー。
/// 期日付きリマインダーはカレンダーグリッド内に、リスト色のドットで表現される。
struct CalendarView: View {
    @EnvironmentObject private var store: ReminderStore
    let reminders: [EKReminder]

    @State private var displayMonth: Date = Date()
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        cal.locale = Locale(identifier: "ja_JP")
        return cal
    }()
    private let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    /// 選択日に該当するリマインダー
    private var remindersForSelectedDay: [EKReminder] {
        reminders.filter { reminder in
            guard let due = store.dueDate(for: reminder) else { return false }
            return calendar.isDate(due, inSameDayAs: selectedDate)
        }
    }

    /// 期日なしリマインダー
    private var datelessReminders: [EKReminder] {
        reminders.filter { store.dueDate(for: $0) == nil }
    }

    /// 選択日の翌日から 7 日間に期日があるリマインダーを「日付 -> 配列」で返す。
    /// 該当する日のみキーに含める。
    private var upcomingWeek: [(date: Date, items: [EKReminder])] {
        let dayMap = remindersByDay
        let start = calendar.startOfDay(for: selectedDate)
        return (1...7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let items = dayMap[date] ?? []
            return items.isEmpty ? nil : (date: date, items: items)
        }
    }

    /// 「日付 -> その日のリマインダー」のインデックス
    private var remindersByDay: [Date: [EKReminder]] {
        var result: [Date: [EKReminder]] = [:]
        for reminder in reminders {
            guard let due = store.dueDate(for: reminder) else { continue }
            let key = calendar.startOfDay(for: due)
            result[key, default: []].append(reminder)
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                monthHeader
                weekdayRow
                grid
                Divider().opacity(0.3).padding(.vertical, 2)
                selectedDaySection
                if !upcomingWeek.isEmpty {
                    Divider().opacity(0.3).padding(.vertical, 2)
                    upcomingSection
                }
                if !datelessReminders.isEmpty {
                    Divider().opacity(0.3).padding(.vertical, 2)
                    datelessSection
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack(spacing: 6) {
            Text(monthLabel)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(Color.primaryText)
            Spacer()
            navButton(systemName: "chevron.left") { changeMonth(-1) }
            navButton(systemName: "circle.fill", small: true) {
                let now = Date()
                withAnimation(.easeInOut(duration: 0.15)) {
                    displayMonth = now
                    selectedDate = calendar.startOfDay(for: now)
                }
            }
            navButton(systemName: "chevron.right") { changeMonth(1) }
        }
    }

    private func navButton(systemName: String, small: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: small ? 5 : 9, weight: .bold))
                .foregroundStyle(small ? MRTheme.accent : Color.secondaryText)
                .frame(width: 22, height: 22)
                .background(Color.black.opacity(0.04), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                Text(weekdays[i])
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(weekdayColor(i))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekdayColor(_ index: Int) -> Color {
        if index == 0 { return Color(red: 0.86, green: 0.36, blue: 0.36) }
        if index == 6 { return Color(red: 0.36, green: 0.56, blue: 0.86) }
        return Color.tertiaryText
    }

    // MARK: - Grid

    private var grid: some View {
        let days = makeDays()
        let dayMap = remindersByDay
        return VStack(spacing: 4) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { col in
                        let day = days[row * 7 + col]
                        let dayKey = calendar.startOfDay(for: day.date)
                        let dayReminders = dayMap[dayKey] ?? []
                        DayCell(
                            day: day,
                            isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                            reminders: dayReminders,
                            calendar: calendar,
                            store: store
                        ) {
                            withAnimation(.easeOut(duration: 0.12)) {
                                selectedDate = day.date
                                if !day.isInMonth {
                                    displayMonth = day.date
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private struct DayInfo {
        let date: Date
        let isInMonth: Bool
        let isToday: Bool
        let weekday: Int
    }

    private func makeDays() -> [DayInfo] {
        let comps = calendar.dateComponents([.year, .month], from: displayMonth)
        guard let firstOfMonth = calendar.date(from: comps) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        guard let startDate = calendar.date(byAdding: .day, value: -firstWeekday, to: firstOfMonth) else { return [] }
        let today = calendar.startOfDay(for: Date())
        let displayMonthValue = calendar.component(.month, from: firstOfMonth)

        return (0..<42).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: startDate)!
            let inMonth = calendar.component(.month, from: date) == displayMonthValue
            let isToday = calendar.isDate(date, inSameDayAs: today)
            let weekday = calendar.component(.weekday, from: date)
            return DayInfo(date: date, isInMonth: inMonth, isToday: isToday, weekday: weekday)
        }
    }

    private struct DayCell: View {
        let day: DayInfo
        let isSelected: Bool
        let reminders: [EKReminder]
        let calendar: Calendar
        let store: ReminderStore
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: day.date))")
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(textColor)
                        .frame(width: 22, height: 22)
                        .background(
                            ZStack {
                                if isSelected {
                                    Circle().fill(MRTheme.accent)
                                } else if day.isToday {
                                    Circle().stroke(MRTheme.accent, lineWidth: 1)
                                }
                            }
                        )

                    dotRow
                }
                .frame(maxWidth: .infinity, minHeight: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }

        /// 下部に最大 3 件分の色ドット、超過分は「+N」テキスト
        private var dotRow: some View {
            let visible = Array(reminders.prefix(3))
            let extra = reminders.count - visible.count

            return HStack(spacing: 2) {
                ForEach(Array(visible.enumerated()), id: \.offset) { _, reminder in
                    Circle()
                        .fill(dotColor(for: reminder))
                        .frame(width: 4, height: 4)
                        .opacity(reminder.isCompleted ? 0.35 : 0.95)
                }
                if extra > 0 {
                    Text("+\(extra)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .frame(height: 6)
            .opacity(day.isInMonth ? 1 : 0.4)
        }

        private func dotColor(for reminder: EKReminder) -> Color {
            store.color(for: reminder.calendar)
        }

        private var textColor: Color {
            if isSelected { return .white }
            if !day.isInMonth { return Color.tertiaryText.opacity(0.45) }
            if day.isToday { return MRTheme.accent }
            if day.weekday == 1 { return Color(red: 0.86, green: 0.36, blue: 0.36) }
            if day.weekday == 7 { return Color(red: 0.36, green: 0.56, blue: 0.86) }
            return Color.primaryText
        }
    }

    // MARK: - Sections below

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(selectedDayLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.secondaryText)
                    .tracking(0.3)
                Text("\(remindersForSelectedDay.count) 件")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.tertiaryText)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)

            if remindersForSelectedDay.isEmpty {
                Text("予定なし")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.tertiaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(remindersForSelectedDay, id: \.calendarItemIdentifier) { reminder in
                        ReminderRow(reminder: reminder)
                            .padding(.horizontal, 4)
                    }
                }
            }
        }
    }

    /// 選択日の翌日から最大 7 日先までを日ごとに並べる
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
                Text("今後 7 日間")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.secondaryText)
                    .tracking(0.3)
                Text("\(upcomingWeek.reduce(0) { $0 + $1.items.count }) 件")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.tertiaryText)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)

            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(upcomingWeek, id: \.date) { day in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Text(dayHeader(for: day.date))
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(weekdayHeaderColor(for: day.date))
                                .tracking(0.3)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 2)

                        ForEach(day.items, id: \.calendarItemIdentifier) { reminder in
                            ReminderRow(reminder: reminder)
                                .padding(.horizontal, 4)
                        }
                    }
                }
            }
        }
    }

    private func dayHeader(for date: Date) -> String {
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日(E)"
        let suffix = f.string(from: date)
        if days == 1 { return "明日 · " + suffix }
        if days == 2 { return "明後日 · " + suffix }
        return suffix
    }

    private func weekdayHeaderColor(for date: Date) -> Color {
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 { return Color(red: 0.86, green: 0.36, blue: 0.36) }
        if weekday == 7 { return Color(red: 0.36, green: 0.56, blue: 0.86) }
        return Color.secondaryText
    }

    private var datelessSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
                Text("期日なし")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.secondaryText)
                    .tracking(0.3)
                Text("\(datelessReminders.count) 件")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.tertiaryText)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)

            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(datelessReminders, id: \.calendarItemIdentifier) { reminder in
                    ReminderRow(reminder: reminder)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - Helpers

    private func changeMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: displayMonth) {
            withAnimation(.easeInOut(duration: 0.18)) {
                displayMonth = next
            }
        }
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年 M月"
        return f.string(from: displayMonth)
    }

    private var selectedDayLabel: String {
        let today = calendar.startOfDay(for: Date())
        if calendar.isDate(selectedDate, inSameDayAs: today) {
            return "今日 · " + DateFormatter.monthDay.string(from: selectedDate)
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日(E)"
        return f.string(from: selectedDate)
    }
}
