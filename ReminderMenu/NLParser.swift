import Foundation

enum NLParser {
    struct SubtaskCandidate: Equatable {
        var title: String
        var memo: String?
    }

    /// 親タスクからサブタスク候補（title + memo）を生成。AI が失敗したら空配列。
    static func generateSubtasks(
        parentTitle: String,
        parentMemo: String?,
        using provider: AIProvider
    ) async -> [SubtaskCandidate] {
        let title = parentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return [] }
        let memo = parentMemo?.trimmingCharacters(in: .whitespacesAndNewlines)

        let prompt = subtaskPrompt(parentTitle: title, parentMemo: memo)
        do {
            let raw = try await provider.runJSON(prompt: prompt, timeoutSeconds: 20)
            let jsonText = extractJSON(from: raw)
            guard let data = jsonText.data(using: .utf8) else { return [] }
            let decoded = try JSONDecoder().decode(SubtaskResponse.self, from: data)
            return decoded.subtasks.compactMap { item in
                let t = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return nil }
                let m = item.memo?.trimmingCharacters(in: .whitespacesAndNewlines)
                return SubtaskCandidate(
                    title: t,
                    memo: (m?.isEmpty ?? true) ? nil : m
                )
            }
        } catch {
            return []
        }
    }

    /// 自然言語をリマインダーに変換。AI が失敗したらローカル日本語パーサーへフォールバック。
    static func parse(
        _ input: String,
        availableLists: [ReminderCalendar],
        using provider: AIProvider
    ) async -> [ReminderDraft] {
        let cleanInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanInput.isEmpty else { return [] }

        if provider.isReady() {
            do {
                let raw = try await provider.runJSON(
                    prompt: parsePrompt(input: cleanInput, availableLists: availableLists),
                    timeoutSeconds: 18
                )
                let jsonText = extractJSON(from: raw)
                if let data = jsonText.data(using: .utf8) {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    if let response = try? decoder.decode(ParseResponse.self, from: data),
                       !response.tasks.isEmpty {
                        return response.tasks.compactMap { task in
                            let title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !title.isEmpty else { return nil }
                            let memo = task.memo?.trimmingCharacters(in: .whitespacesAndNewlines)
                            let urlString = task.url?.trimmingCharacters(in: .whitespacesAndNewlines)
                            return ReminderDraft(
                                title: title,
                                dueDate: task.dueDate,
                                includesTime: task.includesTime,
                                priority: task.priority,
                                listName: task.list,
                                memo: (memo?.isEmpty ?? true) ? nil : memo,
                                url: (urlString?.isEmpty ?? true) ? nil : URL(string: urlString!)
                            )
                        }
                    }
                }
            } catch {
                // フォールバックへ落ちる
            }
        }
        return LocalParser(input: cleanInput, availableLists: availableLists).parse()
    }

    // MARK: - Prompts

    private static func subtaskPrompt(parentTitle: String, parentMemo: String?) -> String {
        let memoBlock = (parentMemo?.isEmpty ?? true) ? "" : "\nParent memo:\n\(parentMemo!)\n"
        return """
        You are an assistant for a macOS Reminders app. The user has a parent task and wants to break it down into concrete, actionable subtasks.

        Parent task: \(parentTitle)
        \(memoBlock)
        Generate 3 to 7 concrete subtasks in Japanese. Each subtask should have:
        - "title": A short imperative phrase (about 5–25 characters), independently actionable. Avoid abstractions like "頑張る" / "計画する". Order roughly by execution sequence.
        - "memo": (optional) A 1–2 sentence note giving more context, hints, or sub-points. Omit when the title is self-explanatory.

        Return JSON only:
        {"subtasks": [
          {"title": "会場を予約する", "memo": "見積もりを 3 社から取り、駐車場の有無を確認"},
          {"title": "招待状を送る"}
        ]}
        """
    }

    private static func parsePrompt(input: String, availableLists: [ReminderCalendar]) -> String {
        let now = ISO8601DateFormatter().string(from: Date())
        let lists = availableLists.map(\.title).joined(separator: ", ")
        return """
        You are a parser for a macOS Reminders menu bar app.
        Today/current time is \(now). Locale is ja_JP and timezone is \(TimeZone.current.identifier).
        Existing reminder lists: \(lists).
        Parse the user text into reminder tasks. Convert relative dates to absolute ISO-8601 datetimes.
        If the user names a list, set "list" to that list name. If no time is specified, set includesTime=false and dueDate at local noon for that date.
        Priority must be 0 for none, 9 for low, 5 for medium, 1 for high.

        Extract these optional fields when the user provides them:
        - "memo": any descriptive notes, context, sub-points, or details. Strip out the time/date/priority/list bits already covered by other fields. If nothing meaningful remains besides the title, omit memo.
        - "url": if the user pastes or mentions a URL (http/https), set it here. Otherwise omit.

        Do NOT invent tags or hashtags. Do not return a "tags" field.

        Return JSON only in this shape (memo and url are optional):
        {"tasks":[{"title":"歯医者","dueDate":"2026-04-28T15:00:00+09:00","includesTime":true,"priority":0,"list":"家事","memo":"治療の続き、保険証持参","url":"https://example.com/clinic"}]}

        User text:
        \(input)
        """
    }
}

// MARK: - Decoders

private struct ParseResponse: Codable {
    var tasks: [ParsedTask]
}

private struct SubtaskResponse: Codable {
    var subtasks: [SubtaskItem]
}

private struct SubtaskItem: Codable {
    var title: String
    var memo: String?
}

private struct ParsedTask: Codable {
    var title: String
    var dueDate: Date?
    var includesTime: Bool
    var priority: Int
    var list: String?
    var memo: String?
    var url: String?
}

// MARK: - Local fallback parser (unchanged from previous implementation)

private struct LocalParser {
    let input: String
    let availableLists: [ReminderCalendar]
    private let calendar = Calendar.current

    func parse() -> [ReminderDraft] {
        var working = input
        let listName = extractListName(from: &working)
        let globalPriority = extractPriority(from: &working)
        let segments = splitSegments(working)

        return segments.compactMap { segment in
            var text = segment
            let extractedURL = extractURL(from: &text)
            let localPriority = extractPriority(from: &text)
            let parsedDate = extractDueDate(from: &text)
            let title = cleanTitle(text)
            guard !title.isEmpty else { return nil }
            return ReminderDraft(
                title: title,
                dueDate: parsedDate.date,
                includesTime: parsedDate.includesTime,
                priority: localPriority ?? globalPriority ?? 0,
                listName: listName,
                memo: nil,
                url: extractedURL
            )
        }
    }

    private func extractURL(from text: inout String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = detector.firstMatch(in: text, range: range),
              let matchRange = Range(match.range, in: text),
              let url = match.url else {
            return nil
        }
        text.removeSubrange(matchRange)
        return url
    }

    private func extractListName(from text: inout String) -> String? {
        let listNames = availableLists
            .map(\.title)
            .sorted { $0.count > $1.count }

        for name in listNames {
            let candidates = [name, "\(name)リスト", normalizedListName(name)]
                .filter { !$0.isEmpty }
            for candidate in candidates where text.localizedCaseInsensitiveContains(candidate) {
                text = text.replacingOccurrences(of: candidate, with: "", options: .caseInsensitive)
                return name
            }
        }

        if text.contains("買い物リスト") {
            text = text.replacingOccurrences(of: "買い物リスト", with: "")
            return "買い物"
        }
        return nil
    }

    private func extractPriority(from text: inout String) -> Int? {
        let checks: [(String, Int)] = [
            ("優先度高", 1), ("高優先度", 1), ("重要", 1),
            ("優先度中", 5), ("優先度普通", 5),
            ("優先度低", 9)
        ]
        for (needle, priority) in checks where text.contains(needle) {
            text = text.replacingOccurrences(of: needle, with: "")
            return priority
        }
        return nil
    }

    private func splitSegments(_ text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "、", with: "と")
            .replacingOccurrences(of: ",", with: "と")

        let parts = normalized.components(separatedBy: "と")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return parts.count > 1 ? parts : [text]
    }

    private func extractDueDate(from text: inout String) -> (date: Date?, includesTime: Bool) {
        let now = Date()
        var day: Date?
        var defaultTime: (hour: Int, minute: Int)?

        if text.contains("明後日") {
            day = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now))
            text = text.replacingOccurrences(of: "明後日", with: "")
        } else if text.contains("明日") {
            day = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            text = text.replacingOccurrences(of: "明日", with: "")
        } else if text.contains("今日") {
            day = calendar.startOfDay(for: now)
            text = text.replacingOccurrences(of: "今日", with: "")
        }

        if let match = firstMatch(text, pattern: "来週([月火水木金土日])曜?") {
            let weekday = weekdayNumber(for: match.groups[0])
            day = nextWeekDate(for: weekday)
            defaultTime = (9, 0)
            text = text.replacingOccurrences(of: match.full, with: "")
        } else if let match = firstMatch(text, pattern: "([月火水木金土日])曜") {
            let weekday = weekdayNumber(for: match.groups[0])
            day = nextDate(for: weekday)
            text = text.replacingOccurrences(of: match.full, with: "")
        } else if text.contains("来週") {
            day = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now))
            defaultTime = (9, 0)
            text = text.replacingOccurrences(of: "来週", with: "")
        }

        let time = extractTime(from: &text)
        guard let day else {
            if let time {
                let today = calendar.startOfDay(for: now)
                return (setTime(time, on: today), true)
            }
            return (nil, false)
        }

        if let time {
            return (setTime(time, on: day), true)
        }
        if let defaultTime {
            return (setTime(defaultTime, on: day), true)
        }
        return (day, false)
    }

    private func extractTime(from text: inout String) -> (hour: Int, minute: Int)? {
        if let match = firstMatch(text, pattern: "(\\d{1,2})[:：](\\d{2})") {
            text = text.replacingOccurrences(of: match.full, with: "")
            return (Int(match.groups[0]) ?? 9, Int(match.groups[1]) ?? 0)
        }

        if let match = firstMatch(text, pattern: "(\\d{1,2})時(半|\\d{1,2}分?)?") {
            text = text.replacingOccurrences(of: match.full, with: "")
            let hour = Int(match.groups[0]) ?? 9
            let minuteText = match.groups.count > 1 ? match.groups[1] : ""
            let minute: Int
            if minuteText == "半" {
                minute = 30
            } else {
                minute = Int(minuteText.replacingOccurrences(of: "分", with: "")) ?? 0
            }
            return (hour, minute)
        }

        return nil
    }

    private func cleanTitle(_ text: String) -> String {
        var title = text
        ["に", "まで", "を買う", "買う", "追加", "タスク"].forEach {
            title = title.replacingOccurrences(of: $0, with: "")
        }
        return title
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private func setTime(_ time: (hour: Int, minute: Int), on date: Date) -> Date? {
        calendar.date(bySettingHour: min(max(time.hour, 0), 23), minute: min(max(time.minute, 0), 59), second: 0, of: date)
    }

    private func nextDate(for weekday: Int) -> Date? {
        let today = calendar.startOfDay(for: Date())
        let current = calendar.component(.weekday, from: today)
        let delta = (weekday - current + 7) % 7
        return calendar.date(byAdding: .day, value: delta == 0 ? 7 : delta, to: today)
    }

    private func nextWeekDate(for weekday: Int) -> Date? {
        let today = calendar.startOfDay(for: Date())
        let currentWeekday = calendar.component(.weekday, from: today)
        let firstWeekday = calendar.firstWeekday
        let daysSinceWeekStart = (currentWeekday - firstWeekday + 7) % 7
        let startOfThisWeek = calendar.date(byAdding: .day, value: -daysSinceWeekStart, to: today) ?? today
        let startOfNextWeek = calendar.date(byAdding: .day, value: 7, to: startOfThisWeek) ?? today
        let offset = (weekday - firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: offset, to: startOfNextWeek)
    }

    private func weekdayNumber(for value: String) -> Int {
        switch value {
        case "日": return 1
        case "月": return 2
        case "火": return 3
        case "水": return 4
        case "木": return 5
        case "金": return 6
        case "土": return 7
        default: return 2
        }
    }

    private func normalizedListName(_ value: String) -> String {
        value.replacingOccurrences(of: "リスト", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func firstMatch(_ text: String, pattern: String) -> RegexMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let fullRange = Range(match.range, in: text) else {
            return nil
        }
        let groups = (1..<match.numberOfRanges).compactMap { index -> String? in
            guard let range = Range(match.range(at: index), in: text) else { return "" }
            return String(text[range])
        }
        return RegexMatch(full: String(text[fullRange]), groups: groups)
    }
}

private struct RegexMatch {
    let full: String
    let groups: [String]
}
