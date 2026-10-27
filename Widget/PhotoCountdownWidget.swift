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
            t = cal.date(byAdding: .minute, value: 30, to: t) ?? t.addingTimeInterval(1800)
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
        if entry.item.savedAt == 0 {
            DiagnosisVisual()
                .widgetBackground()
        } else {
            WidgetVisual(slot: slot,
                         photo: entry.photo,
                         item: entry.item,
                         date: entry.date,
                         debugTag: Self.tag(src: entry.src, item: entry.item))
                .widgetBackground()
        }
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

// MARK: - 诊断视图（没有数据时直接显示通道状态）

struct DiagnosisVisual: View {
    @Environment(\.widgetFamily) var envFamily

    var body: some View {
        let f = WidgetStore.channelFlags()
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        VStack(alignment: .leading, spacing: 5) {
            Text("等待 App 数据")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            Text("B\(f.b ? 1 : 0) E\(f.e ? 1 : 0) M\(f.m ? 1 : 0) F\(f.f ? 1 : 0) D\(f.d ? 1 : 0)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.95))
            Spacer(minLength: 0)
            Text("打开 Love Time 一次即可 · v\(v)")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(
            LinearGradient(colors: [Color(red: 0.13, green: 0.11, blue: 0.18),
                                    Color(red: 0.07, green: 0.06, blue: 0.10)],
                           startPoint: .top, endPoint: .bottom)
        )
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
        StaticConfiguration(kind: "LoveTimeWidget", provider: Provider()) { entry in
            PhotoCountdownView(entry: entry)
        }
        .configurationDisplayName("Love Time")
        .description("照片倒计时 · 每个日子都值得被期待")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
