import Foundation

struct CountdownItem: Codable, Equatable {
    var title: String
    var targetDate: Date

    init(title: String = "倒计时", targetDate: Date = Calendar.current.date(from: DateComponents(year: 2027, month: 1, day: 1)) ?? Date()) {
        self.title = title
        self.targetDate = targetDate
    }
}

enum WidgetSlot: String {
    case small   // 2×2
    case medium  // 2×4
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
}
