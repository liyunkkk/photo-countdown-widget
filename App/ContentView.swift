import SwiftUI
import PhotosUI
import WidgetKit

struct ContentView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("2×2 小组件")) {
                    SlotEditor(slot: .small)
                }
                Section(header: Text("2×4 小组件")) {
                    SlotEditor(slot: .medium)
                }
                Section {
                    Text("使用方法：保存后回到桌面 → 长按空白处 → 添加小组件 → 「照片倒计时」→ 选 2×2 或 2×4。两个尺寸各自独立配置。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("照片倒计时")
        }
    }
}

struct SlotEditor: View {
    let slot: WidgetSlot
    @State private var item: CountdownItem
    @State private var photoData: Data?
    @State private var picked: PhotosPickerItem?
    @State private var tip = ""

    init(slot: WidgetSlot) {
        self.slot = slot
        _item = State(initialValue: WidgetStore.item(for: slot))
        _photoData = State(initialValue: WidgetStore.photoData(for: slot))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let d = photoData, let img = UIImage(data: d) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .clipped()
                    .cornerRadius(10)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                        .frame(height: 110)
                    Text("未选择照片")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            PhotosPicker(selection: $picked, matching: .images) {
                Label("选择照片", systemImage: "photo.on.rectangle")
            }

            TextField("标题（如：距离元旦）", text: $item.title)
                .textFieldStyle(.roundedBorder)

            DatePicker("目标时间", selection: $item.targetDate, displayedComponents: [.date, .hourAndMinute])

            HStack {
                Button {
                    save()
                } label: {
                    Label("保存", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)

                if !tip.isEmpty {
                    Text(tip)
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 6)
        .onChange(of: picked) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
        }
    }

    private func save() {
        WidgetStore.save(item, for: slot)
        if let d = photoData {
            WidgetStore.savePhoto(d, for: slot)
        }
        WidgetCenter.shared.reloadAllTimelines()
        tip = "已保存 ✓ 小组件会自动刷新"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { tip = "" }
    }
}
