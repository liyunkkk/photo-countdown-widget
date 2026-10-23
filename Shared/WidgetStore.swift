import Foundation
import WidgetKit

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
    var savedAt: Double

    private enum CodingKeys: String, CodingKey {
        case title, targetDate, repeatMode, countUpPlusOne, savedAt
    }

    init(title: String = "倒计时",
         targetDate: Date = Calendar.current.date(from: DateComponents(year: 2027, month: 1, day: 1)) ?? Date(),
         repeatMode: RepeatMode = .none,
         countUpPlusOne: Bool = false,
         savedAt: Double = 0) {
        self.title = title
        self.targetDate = targetDate
        self.repeatMode = repeatMode
        self.countUpPlusOne = countUpPlusOne
        self.savedAt = savedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "倒计时"
        targetDate = try c.decodeIfPresent(Date.self, forKey: .targetDate) ?? Date()
        repeatMode = (try? c.decodeIfPresent(RepeatMode.self, forKey: .repeatMode)) ?? .none
        countUpPlusOne = (try? c.decodeIfPresent(Bool.self, forKey: .countUpPlusOne)) ?? false
        savedAt = (try? c.decodeIfPresent(Double.self, forKey: .savedAt)) ?? 0
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
    /// 巨魔兜底通道：不依赖 App Group 的固定路径（需 platform-application 权限）
    static let mediaPath = "/var/mobile/Media/LoveTime"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }
    static var containerURL: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) }

    /// 兜底目录：不存在则创建，并做真实写探测（只探测不写脏文件）
    static var mediaURL: URL? {
        let fm = FileManager.default
        let dir = URL(fileURLWithPath: mediaPath, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            do { try fm.createDirectory(at: dir, withIntermediateDirectories: true) } catch { return nil }
        }
        let probe = dir.appendingPathComponent(".probe")
        do {
            try Data([0x00]).write(to: probe)
            try? fm.removeItem(at: probe)
            return dir
        } catch { return nil }
    }

    /// 可写目录：兜底目录优先，其次 App Group 容器
    static var writableDirs: [URL] {
        var dirs: [URL] = []
        if let d = mediaURL { dirs.append(d) }
        if let d = containerURL { dirs.append(d) }
        return dirs
    }

    /// 三通道写：defaults + 所有可写目录；返回是否至少有一处成功
    @discardableResult
    static func save(_ item: CountdownItem, for slot: WidgetSlot) -> Bool {
        guard let d = try? JSONEncoder().encode(item) else { return false }
        var ok = false
        if let u = defaults {
            u.set(d, forKey: "item.\(slot.rawValue)")
            ok = true
        }
        for dir in writableDirs {
            do {
                try d.write(to: dir.appendingPathComponent("item.\(slot.rawValue).json"), options: .atomic)
                ok = true
            } catch { }
        }
        return ok
    }

    /// 读：三通道全部读一遍，取 savedAt 最新的那份（自动避开某个通道失效）
    static func itemWithSource(for slot: WidgetSlot) -> (CountdownItem, String) {
        var best: (CountdownItem, String)? = nil
        func consider(_ d: Data?, _ tag: String) {
            guard let d = d, let it = try? JSONDecoder().decode(CountdownItem.self, from: d) else { return }
            if best == nil || it.savedAt > best!.0.savedAt { best = (it, tag) }
        }
        if let m = mediaURL {
            consider(try? Data(contentsOf: m.appendingPathComponent("item.\(slot.rawValue).json")), "M")
        }
        if let c = containerURL {
            consider(try? Data(contentsOf: c.appendingPathComponent("item.\(slot.rawValue).json")), "F")
        }
        consider(defaults?.data(forKey: "item.\(slot.rawValue)"), "D")
        if let b = best { return b }
        return (CountdownItem(), "—")
    }

    static func item(for slot: WidgetSlot) -> CountdownItem {
        itemWithSource(for: slot).0
    }

    /// 照片写入所有可写目录；返回是否至少一处成功
    @discardableResult
    static func savePhoto(_ data: Data, for slot: WidgetSlot) -> Bool {
        var ok = false
        for dir in writableDirs {
            do {
                try data.write(to: dir.appendingPathComponent("photo.\(slot.rawValue).img"), options: .atomic)
                ok = true
            } catch { }
        }
        return ok
    }

    static func photoData(for slot: WidgetSlot) -> Data? {
        for dir in writableDirs {
            let u = dir.appendingPathComponent("photo.\(slot.rawValue).img")
            if FileManager.default.fileExists(atPath: u.path),
               let d = try? Data(contentsOf: u), !d.isEmpty {
                return d
            }
        }
        return nil
    }

    static func clearPhoto(for slot: WidgetSlot) {
        for dir in writableDirs {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("photo.\(slot.rawValue).img"))
        }
        defaults?.removeObject(forKey: "photo.\(slot.rawValue)")
    }

    static func reloadTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func shortPath(_ p: String) -> String {
        p.split(separator: "/").suffix(2).joined(separator: "/")
    }

    /// 诊断：三条通道逐个报告
    static func diagnosis() -> [String] {
        var lines: [String] = []
        lines.append("M 兜底目录: " + (mediaURL != nil ? "✅ 可写" : "❌ 不可用"))
        if let c = containerURL {
            lines.append("F App Group: ✅ \(shortPath(c.path))")
        } else {
            lines.append("F App Group: ❌ nil")
        }
        lines.append("D defaults: " + (defaults != nil ? "对象可用" : "nil"))
        for slot in WidgetSlot.allCases {
            let (it, src) = itemWithSource(for: slot)
            let photo = photoData(for: slot).map { "\($0.count / 1024)KB" } ?? "无"
            lines.append("\(slot.rawValue): [\(src)] 标题「\(it.title)」照片 \(photo)")
        }
        return lines
    }
}
