import Foundation

enum RepeatMode: Int, Codable, CaseIterable, Identifiable {
    case none = 0
    case weekly = 1
    case monthly = 2
    case yearly = 3

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .none: return "不重复"
        case .weekly: return "每周"
        case .monthly: return "每月"
        case .yearly: return "每年"
        }
    }
}

struct CountdownItem: Codable, Equatable {
    var title: String
    var targetDate: Date
    var repeatMode: RepeatMode
    var countUpPlusOne: Bool

    private enum CodingKeys: String, CodingKey {
        case title, targetDate, repeatMode, countUpPlusOne
    }

    init(title: String = "倒计时",
         targetDate: Date = Calendar.current.date(from: DateComponents(year: 2027, month: 1, day: 1)) ?? Date(),
         repeatMode: RepeatMode = .none,
         countUpPlusOne: Bool = false) {
        self.title = title
        self.targetDate = targetDate
        self.repeatMode = repeatMode
        self.countUpPlusOne = countUpPlusOne
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "倒计时"
        targetDate = try c.decodeIfPresent(Date.self, forKey: .targetDate) ?? Date()
        repeatMode = (try? c.decodeIfPresent(RepeatMode.self, forKey: .repeatMode)) ?? .none
        countUpPlusOne = (try? c.decodeIfPresent(Bool.self, forKey: .countUpPlusOne)) ?? false
    }

    /// 处理重复后的实际目标时间
    func resolvedTarget(after now: Date, calendar: Calendar = .current) -> Date {
        if repeatMode == .none || targetDate >= now { return targetDate }
        let cal = calendar
        let time = cal.dateComponents([.hour, .minute, .second], from: targetDate)
        switch repeatMode {
        case .none:
            return targetDate
        case .weekly:
            let wd = cal.component(.weekday, from: targetDate)
            var d = cal.startOfDay(for: now)
            while cal.component(.weekday, from: d) != wd {
                d = cal.date(byAdding: .day, value: 1, to: d) ?? d
            }
            var c = cal.dateComponents([.year, .month, .day], from: d)
            c.hour = time.hour; c.minute = time.minute; c.second = time.second
            guard let cand = cal.date(from: c) else { return targetDate }
            return cand < now ? (cal.date(byAdding: .day, value: 7, to: cand) ?? cand) : cand
        case .monthly:
            let day = cal.component(.day, from: targetDate)
            var c = cal.dateComponents([.year, .month], from: now)
            c.day = day; c.hour = time.hour; c.minute = time.minute; c.second = time.second
            guard var cand = cal.date(from: c) else { return targetDate }
            if cand < now { cand = cal.date(byAdding: .month, value: 1, to: cand) ?? cand }
            return cand
        case .yearly:
            let m = cal.component(.month, from: targetDate)
            let d = cal.component(.day, from: targetDate)
            var c = cal.dateComponents([.year], from: now)
            c.month = m; c.day = d; c.hour = time.hour; c.minute = time.minute; c.second = time.second
            guard var cand = cal.date(from: c) else { return targetDate }
            if cand < now { cand = cal.date(byAdding: .year, value: 1, to: cand) ?? cand }
            return cand
        }
    }

    /// 纯时间差：days = 完整天数，h/m 为余数（与参考设计一致：1,631天 12小时38分钟）
    func displayComponents(from date: Date, calendar: Calendar = .current) -> (days: Int, hours: Int, minutes: Int, future: Bool) {
        let target = resolvedTarget(after: date, calendar: calendar)
        let future = target >= date
        let secs = Int(abs(target.timeIntervalSince(date)))
        var days = secs / 86400
        if !future && countUpPlusOne { days += 1 }
        return (days, (secs / 3600) % 24, (secs / 60) % 60, future)
    }
}

enum WidgetStore {
    static let appGroupId = "group.com.qingxu.photowidget"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
    }

    static func item(for slot: WidgetSlot) -> CountdownItem {
        if let d = defaults?.data(forKey: "item.\(slot.rawValue)"),
           let it = try? JSONDecoder().decode(CountdownItem.self, from: d) {
            return it
        }
        return CountdownItem()
    }

    static func save(_ item: CountdownItem, for slot: WidgetSlot) {
        if let d = try? JSONEncoder().encode(item) {
            defaults?.set(d, forKey: "item.\(slot.rawValue)")
        }
    }

    static func savePhoto(_ data: Data, for slot: WidgetSlot) {
        guard let dir = containerURL else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("photo.\(slot.rawValue).img")
        try? data.write(to: url, options: .atomic)
    }

    static func photoData(for slot: WidgetSlot) -> Data? {
        guard let dir = containerURL else { return nil }
        let url = dir.appendingPathComponent("photo.\(slot.rawValue).img")
        return FileManager.default.fileExists(atPath: url.path) ? (try? Data(contentsOf: url)) : nil
    }

    static func reloadTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
