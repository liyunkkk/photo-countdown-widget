import SwiftUI
import UIKit

enum WidgetSlot: String, CaseIterable, Identifiable {
    case small
    case medium

    var id: String { rawValue }
    var label: String { self == .small ? "2×2 小组件" : "2×4 小组件" }
}

/// 小组件与 App 预览共用的视觉渲染 —— 全幅照片 + 顶部日期 + 底部倒计时大数字
struct WidgetVisual: View {
    let slot: WidgetSlot
    let photo: UIImage?
    let item: CountdownItem
    let date: Date

    private var c: (days: Int, hours: Int, minutes: Int, future: Bool) {
        item.displayComponents(from: date)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                background
                    .overlay(
                        LinearGradient(
                            colors: [.black.opacity(0.42), .black.opacity(0.04), .black.opacity(0.62)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                VStack(alignment: .leading, spacing: 0) {
                    dateHeader
                    Spacer(minLength: 0)
                    footer
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(slot == .small ? 11 : 13)
            }
            .clipped()
        }
    }

    @ViewBuilder
    private var background: some View {
        if let img = photo {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.42, blue: 0.56),
                    Color(red: 0.62, green: 0.26, blue: 0.72)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(Self.dateString(date))
                .font(.system(size: slot == .small ? 11 : 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            if slot == .medium {
                Text(Self.weekdayString(date))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: slot == .small ? 0 : 1) {
            if c.future && c.days == 0 {
                Text("就是今天")
                    .font(.system(size: slot == .small ? 26 : 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            } else {
                Text(item.title)
                    .font(.system(size: slot == .small ? 11 : 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.94))
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(c.days.formatted())
                        .font(.system(size: slot == .small ? 33 : 42, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("天")
                        .font(.system(size: slot == .small ? 14 : 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                }
                Text("\(c.hours)小时\(c.minutes)分钟")
                    .font(.system(size: slot == .small ? 11 : 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
            }
        }
        .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
    }

    static func dateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f.string(from: d)
    }

    static func weekdayString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        f.locale = Locale(identifier: "zh_CN")
        return f.string(from: d)
    }
}

/// 图片降采样，避免小组件加载大图
enum PhotoCoder {
    static func downscaledData(from data: Data, maxSide: CGFloat = 1200) -> Data? {
        guard let img = UIImage(data: data) else { return nil }
        let scale = min(1, maxSide / max(img.size.width, img.size.height))
        let target = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let out = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: target)) }
        return out.jpegData(compressionQuality: 0.86)
    }
}
