import WidgetKit
import SwiftUI

// MARK: - Timeline

struct PhotoEntry: TimelineEntry {
    let date: Date
    let item: CountdownItem
    let photo: UIImage?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> PhotoEntry {
        PhotoEntry(date: Date(),
                   item: CountdownItem(title: "恋爱中",
                                       targetDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()),
                   photo: nil)
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
        let item = WidgetStore.item(for: s)
        let photo = WidgetStore.photoData(for: s).flatMap { UIImage(data: $0) }
        return PhotoEntry(date: date, item: item, photo: photo)
    }
}

// MARK: - View

struct PhotoCountdownView: View {
    @Environment(\.widgetFamily) var family
    var entry: PhotoEntry

    var body: some View {
        let slot: WidgetSlot = (family == .systemSmall) ? .small : .medium
        WidgetVisual(slot: slot,
                     photo: WidgetStore.photoData(for: slot).flatMap { UIImage(data: $0) },
                     item: WidgetStore.item(for: slot),
                     date: entry.date)
            .widgetBackground()
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
