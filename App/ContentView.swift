import SwiftUI

struct ContentView: View {
    @State private var slot: WidgetSlot = .small
    @State private var item = CountdownItem()
    @State private var photo: UIImage?
    @State private var showPicker = false
    @State private var savedFlash = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                slotPicker
                previewCard
                editorCard
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .sheet(isPresented: $showPicker) {
            PhotoPicker { data in
                if let data,
                   let small = PhotoCoder.downscaledData(from: data, maxSide: 1200),
                   let img = UIImage(data: small) {
                    photo = img
                    WidgetStore.savePhoto(small, for: slot)
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: slot) { _ in load() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.36, blue: 0.50),
                                                  Color(red: 0.75, green: 0.28, blue: 0.85)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 44, height: 44)
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

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("预览")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            WidgetVisual(slot: slot, photo: photo, item: item, date: Date())
                .frame(height: slot == .small ? 155 : 155)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 8, y: 3)
        }
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("标题")
                Spacer()
                TextField("如：恋爱中", text: $item.title)
                    .multilineTextAlignment(.trailing)
                    .font(.body.weight(.semibold))
                    .frame(width: 180)
            }
            Divider()
            DatePicker("目标日", selection: $item.targetDate)
                .environment(\.locale, Locale(identifier: "zh_CN"))
            Divider()
            HStack {
                Text("事件重复")
                Spacer()
                Picker("", selection: $item.repeatMode) {
                    ForEach(RepeatMode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .font(.body.weight(.semibold))
            }
            Toggle(isOn: $item.countUpPlusOne) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("正数时计算起始日")
                    Text("过期后按 +1 天起算")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(Color(red: 1.0, green: 0.36, blue: 0.50))
            Divider()
            photoRow
            saveButton
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var photoRow: some View {
        HStack {
            Text("照片")
            Spacer()
            if photo != nil {
                Button(role: .destructive) {
                    photo = nil
                    try? FileManager.default.removeItem(at: WidgetStore.containerURL!.appendingPathComponent("photo.\(slot.rawValue).img"))
                } label: {
                    Label("移除", systemImage: "trash")
                        .font(.footnote.weight(.medium))
                }
                .buttonStyle(.borderless)
            }
            Button {
                showPicker = true
            } label: {
                Label(photo == nil ? "选取" : "更换", systemImage: "photo")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.borderless)
        }
    }

    private var saveButton: some View {
        Button {
            WidgetStore.save(item, for: slot)
            WidgetStore.reloadTimelines()
            savedFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { savedFlash = false }
        } label: {
            HStack {
                Image(systemName: savedFlash ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                Text(savedFlash ? "已保存，小组件已刷新" : "保存并刷新小组件")
                    .font(.body.weight(.bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.36, blue: 0.50),
                                                  Color(red: 0.75, green: 0.28, blue: 0.85)],
                                         startPoint: .leading, endPoint: .trailing))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private func load() {
        item = WidgetStore.item(for: slot)
        photo = WidgetStore.photoData(for: slot).flatMap { UIImage(data: $0) }
    }
}

// MARK: - PhotosPicker

import PhotosUI

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
