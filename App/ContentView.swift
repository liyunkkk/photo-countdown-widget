import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @State private var slot: WidgetSlot = .small
    @State private var item = CountdownItem()
    @State private var photo: UIImage?
    @State private var showPicker = false
    @State private var savedFlash = false
    @State private var saveError: String?
    @State private var showDiag = false
    @State private var diag: [String] = []

    private let accent = Color(red: 1.0, green: 0.36, blue: 0.50)

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                slotPicker
                previewSection
                editorCard
                saveButton
                if let err = saveError { errorBanner(err) }
                diagnosisCard
                tips
            }
            .padding(14)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .sheet(isPresented: $showPicker) {
            PhotoPicker { data in
                guard let data,
                      let small = PhotoCoder.downscaledData(from: data, maxSide: 1200),
                      let img = UIImage(data: small) else { return }
                photo = img
                saveError = nil
            }
        }
        .onAppear(perform: load)
        .onChange(of: slot) { _ in load() }
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(colors: [accent, Color(red: 0.72, green: 0.27, blue: 0.85)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "heart.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text("Love Time")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                Text("每个日子都值得被期待")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    private var slotPicker: some View {
        Picker("", selection: $slot) {
            ForEach(WidgetSlot.allCases) { s in
                Text(s.label).tag(s)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - 预览

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("预览 · 与桌面一致")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Group {
                if slot == .small {
                    WidgetVisual(slot: slot, photo: photo, item: item, date: Date())
                        .frame(width: 164, height: 164)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                        .frame(maxWidth: .infinity)
                } else {
                    WidgetVisual(slot: slot, photo: photo, item: item, date: Date())
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: slot)
        }
    }

    // MARK: - 编辑区（一张卡片，固定行序）

    private var editorCard: some View {
        VStack(spacing: 0) {
            titleRow
            divider
            dateRow
            divider
            repeatRow
            divider
            countUpRow
            divider
            photoRow
        }
        .padding(.horizontal, 15)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var divider: some View {
        Divider().overlay(Color.primary.opacity(0.08))
    }

    private var titleRow: some View {
        HStack {
            rowLabel("标题", icon: "textformat")
            Spacer()
            TextField("如：老婆 / 恋爱中", text: $item.title)
                .multilineTextAlignment(.trailing)
                .font(.body.weight(.semibold))
                .frame(width: 190)
        }
        .padding(.vertical, 13)
    }

    private var dateRow: some View {
        HStack {
            rowLabel("目标日", icon: "calendar")
            Spacer()
            DatePicker("", selection: $item.targetDate, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "zh_CN"))
        }
        .padding(.vertical, 10)
    }

    private var repeatRow: some View {
        VStack(alignment: .leading, spacing: 9) {
            rowLabel("事件重复", icon: "arrow.triangle.2.circlepath")
            HStack(spacing: 7) {
                ForEach(RepeatMode.allCases) { m in
                    let on = item.repeatMode == m
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { item.repeatMode = m }
                    } label: {
                        Text(m.label)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(on ? .white : .primary.opacity(0.55))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(on ? AnyShapeStyle(accent) : AnyShapeStyle(Color.primary.opacity(0.07))))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
        .padding(.vertical, 12)
    }

    private var countUpRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("正数时计算起始日")
                    .font(.subheadline)
                Text("过期后把目标日当天算作第 1 天")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $item.countUpPlusOne)
                .labelsHidden()
                .tint(accent)
        }
        .padding(.vertical, 11)
    }

    private var photoRow: some View {
        HStack(spacing: 10) {
            rowLabel("照片", icon: "photo")
            Spacer()
            if let img = photo {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                Button {
                    showPicker = true
                } label: {
                    Text("更换")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(accent)
                }
                .buttonStyle(.plain)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { photo = nil }
                } label: {
                    Text("移除")
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    showPicker = true
                } label: {
                    Label("选取", systemImage: "plus.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 11)
    }

    private func rowLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.medium))
            .foregroundColor(.primary.opacity(0.75))
    }

    // MARK: - 保存

    private var saveButton: some View {
        Button(action: save) {
            HStack(spacing: 7) {
                Image(systemName: savedFlash ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath.circle.fill")
                Text(savedFlash ? "已保存 · 小组件刷新中" : "保存并刷新小组件")
                    .font(.body.weight(.bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(LinearGradient(colors: [accent, Color(red: 0.72, green: 0.27, blue: 0.85)],
                                         startPoint: .leading, endPoint: .trailing))
            )
        }
        .buttonStyle(.plain)
    }

    private func save() {
        WidgetStore.save(item, for: slot)

        var photoOK = true
        if let img = photo {
            if let d = img.jpegData(compressionQuality: 0.9) {
                photoOK = WidgetStore.savePhoto(d, for: slot)
            }
        } else {
            WidgetStore.clearPhoto(for: slot)
        }

        WidgetStore.reloadTimelines()
        UINotificationFeedbackGenerator().notificationOccurred(photoOK ? .success : .warning)
        withAnimation { savedFlash = true; if !photoOK { saveError = "照片没能写入 App Group 容器（数据通道可能断了，展开下方诊断查看）" } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { savedFlash = false }
        }
        diag = WidgetStore.diagnosis()
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text).font(.footnote)
            Spacer()
        }
        .foregroundColor(.orange)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.orange.opacity(0.12)))
    }

    // MARK: - 诊断

    private var diagnosisCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                diag = WidgetStore.diagnosis()
                withAnimation { showDiag.toggle() }
            } label: {
                HStack {
                    Label("数据通道诊断", systemImage: "waveform.path.ecg")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: showDiag ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            if showDiag {
                ForEach(diag, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Text("若显示 ❌：删除桌面小组件 → 巨魔重装 IPA → 重开本 App 保存 → 重新添加小组件")
                    .font(.caption2)
                    .foregroundColor(.orange.opacity(0.85))
            }
        }
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var tips: some View {
        Text("桌面长按空白 → ＋ → 搜索 Love Time → 添加 2×2 / 2×4。每个尺寸对应这里各自的配置。")
            .font(.caption2)
            .foregroundColor(.secondary.opacity(0.7))
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.bottom, 8)
    }

    // MARK: - 数据

    private func load() {
        item = WidgetStore.item(for: slot)
        photo = WidgetStore.photoData(for: slot).flatMap { UIImage(data: $0) }
        diag = WidgetStore.diagnosis()
    }
}

// MARK: - PHPicker

struct PhotoPicker: UIViewControllerRepresentable {
    let onPick: (Data?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var c = PHPickerConfiguration()
        c.filter = .images
        c.selectionLimit = 1
        let v = PHPickerViewController(configuration: c)
        v.delegate = context.coordinator
        return v
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            defer { parent.dismiss() }
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                parent.onPick(nil); return
            }
            provider.loadObject(ofClass: UIImage.self) { obj, _ in
                let parent = self.parent
                DispatchQueue.main.async {
                    guard let img = obj as? UIImage else { parent.onPick(nil); return }
                    parent.onPick(img.jpegData(compressionQuality: 0.92))
                }
            }
        }
    }
}
