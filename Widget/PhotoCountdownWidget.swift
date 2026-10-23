import WidgetKit
import SwiftUI

// MARK: - Timeline

struct PhotoEntry: TimelineEntry {
    let date: Date
    let item: CountdownItem
    let photo: UIImage?
    let src: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> PhotoEntry {
        PhotoEntry(date: Date(),
                   item: CountdownItem(title: "恋爱中",
                                       targetDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()),
                   photo: nil, src: "—")
    }

    func getSnapshot(in context: Context, completion: @escaping (PhotoEntry) -> Void) {
        completion(entry(for: context, at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PhotoEntry>) -> Void) {
        let cal = Calendar.current
        var entries: [PhotoEntry] = []
        var t = Date()
        for _ in 0..<24 {
            entries.append(entry(for: context, at: t))
            t = cal.date(byAdding: .minute, value: 60, to: t) ?? t.addingTimeInterval(3600)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func slot(for context: Context) -> WidgetSlot {
        context.family == .systemSmall ? .small : .medium
    }

    private func entry(for context: Context, at date: Date) -> PhotoEntry {
        let s = slot(for: context)
        let (item, src) = WidgetStore.itemWithSource(for: s)
        let photo = WidgetStore.photoData(for: s).flatMap { UIImage(data: $0) }
        return PhotoEntry(date: date, item: item, photo: photo, src: src)
    }
}

// MARK: - View

struct PhotoCountdownView: View {
    @Environment(\.widgetFamily) var family
    var entry: PhotoEntry

    var body: some View {
        let slot: WidgetSlot = (family == .systemSmall) ? .small : .medium
        WidgetVisual(slot: slot,
                     photo: entry.photo,
                     item: entry.item,
                     date: entry.date,
                     debugTag: Self.tag(src: entry.src, item: entry.item))
            .widgetBackground()
    }

    /// 右上角调试水印：v版本 通道 保存时间（如 v12 F 14:05）
    static func tag(src: String, item: CountdownItem) -> String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        guard item.savedAt > 0 else { return "v\(v) \(src)" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "v\(v) \(src) \(f.string(from: Date(timeIntervalSince1970: item.savedAt)))"
    }
}

extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) { self }
        } else {
            self
        }
    }
}

// MARK: - Widget

@main
struct PhotoCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PhotoCountdown", provider: Provider()) { entry in
            PhotoCountdownView(entry: entry)
        }
        .configurationDisplayName("Love Time")
        .description("照片倒计时 · 每个日子都值得被期待")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
