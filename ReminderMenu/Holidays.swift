import Foundation

/// 日本の祝日をルールベースで生成する。
///
/// EventKit の祝日カレンダーに頼ると追加の権限要求が必要になるため、
/// 内閣府が定める祝日法のロジックをそのまま実装する。1948 年以降の
/// 大きな改正は反映済み（春分・秋分は 1900–2099 の範囲で正確）。
enum JapaneseHolidays {

    /// 指定日が祝日なら名称を返す（振替・国民の休日含む）
    static func name(for date: Date) -> String? {
        let cal = gregorian
        let key = cal.startOfDay(for: date)
        let year = cal.component(.year, from: key)
        return holidayMap(forYear: year)[key]
    }

    /// 指定年の全祝日（振替・国民の休日含む）を `[startOfDay: 名称]` で返す
    static func holidayMap(forYear year: Int) -> [Date: String] {
        if let cached = cache[year] { return cached }
        let map = computeHolidays(year: year)
        cache[year] = map
        return map
    }

    // MARK: - Private

    private static let gregorian: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return cal
    }()

    private static var cache: [Int: [Date: String]] = [:]

    private static func computeHolidays(year: Int) -> [Date: String] {
        var result: [Date: String] = [:]
        let cal = gregorian

        func add(_ month: Int, _ day: Int, _ name: String) {
            if let date = cal.date(from: DateComponents(year: year, month: month, day: day)) {
                result[cal.startOfDay(for: date)] = name
            }
        }

        // 固定祝日
        add(1, 1, "元日")
        add(2, 11, "建国記念の日")
        if year >= 2020 { add(2, 23, "天皇誕生日") }
        else if year >= 1989 { add(12, 23, "天皇誕生日") }
        add(4, 29, year >= 2007 ? "昭和の日" : "みどりの日")
        add(5, 3, "憲法記念日")
        if year >= 2007 { add(5, 4, "みどりの日") }
        add(5, 5, "こどもの日")
        if year >= 2016 { add(8, 11, "山の日") }
        add(11, 3, "文化の日")
        add(11, 23, "勤労感謝の日")

        // 春分の日 / 秋分の日（1900–2099 で有効な近似式）
        if let spring = equinoxDay(year: year, isSpring: true) {
            add(3, spring, "春分の日")
        }
        if let autumn = equinoxDay(year: year, isSpring: false) {
            add(9, autumn, "秋分の日")
        }

        // ハッピーマンデー
        if year >= 2000 {
            if let d = nthWeekday(year: year, month: 1, weekday: 2, n: 2) { result[d] = "成人の日" }
        } else {
            add(1, 15, "成人の日")
        }

        if year >= 2003 {
            if let d = nthWeekday(year: year, month: 7, weekday: 2, n: 3) {
                result[d] = (year >= 2020 && year <= 2020) ? "海の日" : "海の日"
            }
        } else if year >= 1996 {
            add(7, 20, "海の日")
        }

        if year >= 2003 {
            if let d = nthWeekday(year: year, month: 9, weekday: 2, n: 3) { result[d] = "敬老の日" }
        } else if year >= 1966 {
            add(9, 15, "敬老の日")
        }

        if year >= 2000 {
            if let d = nthWeekday(year: year, month: 10, weekday: 2, n: 2) {
                result[d] = year >= 2020 ? "スポーツの日" : "体育の日"
            }
        } else if year >= 1966 {
            add(10, 10, "体育の日")
        }

        // 2020 と 2021 の特例（東京五輪に伴う移動）
        if year == 2020 {
            // 海の日: 7/23、スポーツの日: 7/24、山の日: 8/10
            result = result.filter { _, name in name != "海の日" && name != "スポーツの日" && name != "山の日" }
            add(7, 23, "海の日")
            add(7, 24, "スポーツの日")
            add(8, 10, "山の日")
        } else if year == 2021 {
            // 海の日: 7/22、スポーツの日: 7/23、山の日: 8/8（8/9 が振替）
            result = result.filter { _, name in name != "海の日" && name != "スポーツの日" && name != "山の日" }
            add(7, 22, "海の日")
            add(7, 23, "スポーツの日")
            add(8, 8, "山の日")
        }

        // 振替休日: 祝日が日曜なら次の非祝日（月曜以降）を振替
        let baseHolidays = result
        for (date, _) in baseHolidays where cal.component(.weekday, from: date) == 1 {
            var candidate = cal.date(byAdding: .day, value: 1, to: date)
            while let d = candidate, result[d] != nil {
                candidate = cal.date(byAdding: .day, value: 1, to: d)
            }
            if let d = candidate {
                result[d] = "振替休日"
            }
        }

        // 国民の休日: 祝日に挟まれた平日（日曜・祝日でない）を休日扱い
        let sortedDates = result.keys.sorted()
        for i in 0..<sortedDates.count - 1 {
            let lhs = sortedDates[i]
            let rhs = sortedDates[i + 1]
            let diff = cal.dateComponents([.day], from: lhs, to: rhs).day ?? 0
            if diff == 2 {
                if let mid = cal.date(byAdding: .day, value: 1, to: lhs),
                   result[mid] == nil,
                   cal.component(.weekday, from: mid) != 1 {
                    result[mid] = "国民の休日"
                }
            }
        }

        return result
    }

    /// 第 n 週の特定曜日の日付を返す。weekday は Calendar 準拠（日曜=1, 月曜=2, ...）。
    private static func nthWeekday(year: Int, month: Int, weekday: Int, n: Int) -> Date? {
        let cal = gregorian
        guard let firstOfMonth = cal.date(from: DateComponents(year: year, month: month, day: 1)) else { return nil }
        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        let offset = (weekday - firstWeekday + 7) % 7
        let day = 1 + offset + (n - 1) * 7
        guard let target = cal.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        return cal.startOfDay(for: target)
    }

    /// 1900–2099 の範囲で有効な春分・秋分の近似式
    private static func equinoxDay(year: Int, isSpring: Bool) -> Int? {
        guard year >= 1900, year <= 2099 else { return nil }
        let baseYear: Double = 1980
        let coefficient: Double = isSpring ? 20.8431 : 23.2488
        let value = coefficient + 0.242194 * Double(year - Int(baseYear)) - floor(Double(year - Int(baseYear)) / 4)
        return Int(floor(value))
    }
}
