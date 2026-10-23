import SwiftUI
import UIKit

enum WidgetSlot: String, CaseIterable, Identifiable {
    case small
    case medium

    var id: String { rawValue }
    var label: String { self == .small ? "2×2 小组件" : "2×4 小组件" }
}

/// 小组件与 App 预览共用的视觉渲染
/// 分层结构：全幅照片打底 → 上:日期（左）/重复标记（右）→ 底部:标题+大数字+时分
struct WidgetVisual: View {
    let slot: WidgetSlot
    let photo: UIImage?
    let item: CountdownItem
    let date: Date
    var debugTag: String = ""   // 调试用右上角水印，App 预览留空

    private var isSmall: Bool { slot == .small }

    private var c: (days: Int, hours: Int, minutes: Int, future: Bool) {
        item.displayComponents(from: date)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                background(width: geo.size.width, height: geo.size.height)
                scrim
                content
                    // 关键：必须让 VStack 撑满整个小组件，Spacer 才能把底部块压下去
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(isSmall ? 12 : 14)
                if !debugTag.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(debugTag)
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.trailing, 9)
                                .padding(.bottom, 6)
                        }
                    }
                }
            }
            .clipped()
        }
    }

    // MARK: 背景层

    @ViewBuilder
    private func background(width: CGFloat, height: CGFloat) -> some View {
        if let img = photo {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
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

    /// 遮罩：顶部压暗保日期，中部透出照片，底部压暗保大数字
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.30), location: 0),
                .init(color: .black.opacity(0.04), location: 0.38),
                .init(color: .black.opacity(0.14), location: 0.58),
                .init(color: .black.opacity(0.70), location: 1.0)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    // MARK: 内容层

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 0)
            footer
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(Self.dateString(date))
                .font(.system(size: isSmall ? 10.5 : 12.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.96))
            Spacer(minLength: 4)
            if !isSmall && item.repeatMode != .none {
                Text("↻ " + item.repeatMode.label)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.78))
            }
        }
        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: isSmall ? 1 : 3) {
            if c.future && c.days == 0 {
                Text(item.title.isEmpty ? "今天" : item.title)
                    .font(.system(size: isSmall ? 11.5 : 13.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                Text("就是今天")
                    .font(.system(size: isSmall ? 26 : 36, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            } else {
                if !item.title.isEmpty {
                    Text(item.title)
                        .font(.system(size: isSmall ? 11.5 : 13.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(daysText)
                        .font(.system(size: isSmall ? 30 : 41, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                    Text("天")
                        .font(.system(size: isSmall ? 13.5 : 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                }
                Text("\(c.hours)小时\(c.minutes)分钟")
                    .font(.system(size: isSmall ? 11 : 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.90))
            }
        }
        .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
    }

    private var daysText: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: c.days)) ?? "\(c.days)"
    }

    static func dateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
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
