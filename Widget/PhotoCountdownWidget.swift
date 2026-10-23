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
        PhotoEntry(date: Date(), item: CountdownItem(title: "倒计时", targetDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()), photo: nil)
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

// MARK: - Widget

@main
struct PhotoCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PhotoCountdown", provider: Provider()) { entry in
            PhotoCountdownView(entry: entry)
        }
        .configurationDisplayName("照片倒计时")
        .description("照片 + 倒计时。在 App 里配置内容。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - View

struct PhotoCountdownView: View {
    @Environment(\.widgetFamily) var family
    let entry: PhotoEntry

    var body: some View {
        Group {
            if family == .systemSmall {
                smallLayout
            } else {
                mediumLayout
            }
        }
        .widgetBackground {
            if let photo = entry.photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Color(red: 0.25, green: 0.27, blue: 0.55), Color(red: 0.08, green: 0.09, blue: 0.18)], startPoint: .top, endPoint: .bottom)
            }
        }
    }

    // 2×2：全幅照片 + 底部倒计时
    private var smallLayout: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.item.title.isEmpty ? "倒计时" : entry.item.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                Text(dayText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(12)
        }
    }

    // 2×4：左照片右文字
    private var mediumLayout: some View {
        HStack(spacing: 12) {
            if let photo = entry.photo {
                GeometryReader { geo in
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .cornerRadius(12)
                }
                .frame(maxWidth: 90)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.item.title.isEmpty ? "倒计时" : entry.item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(dayText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(dateText)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(2)
    }

    private var dayText: String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: entry.date), to: cal.startOfDay(for: entry.item.targetDate)).day ?? 0
        if days > 0 {
            if family == .systemMedium {
                let hours = max(0, (cal.dateComponents([.hour], from: entry.date, to: entry.item.targetDate).hour ?? 0) % 24)
                return "\(days) 天 \(hours) 小时"
            }
            return "\(days) 天"
        }
        if days == 0 { return "就是今天" }
        return "已过 \(-days) 天"
    }

    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: entry.item.targetDate)
    }
}

// MARK: - iOS 16/17 兼容背景

extension View {
    @ViewBuilder
    func widgetBackground(@ViewBuilder _ bg: () -> some View) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget, background: bg)
        } else {
            background(bg())
        }
    }
}
