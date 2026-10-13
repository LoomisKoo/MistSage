import SwiftUI
import SwiftData

struct AddAssetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editing: AssetItem?

    @State private var name = ""
    @State private var summary = ""
    @State private var priceText = ""
    @State private var useCountText = "0"
    @State private var kind: AssetKind = .durable
    @State private var status: AssetStockStatus = .plenty
    @State private var iconName = AssetIconOption.cube.rawValue
    @State private var isPublic = false
    @State private var showIconPicker = false
    @State private var showLibrary = false
    @State private var draftPhoto: UIImage?
    @State private var removePhoto = false
    @State private var acquiredAt = Date()
    @State private var setAcquiredAt = false

    private var price: Double { Double(priceText) ?? 0 }
    private var useCount: Int { Int(useCountText) ?? 0 }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isEditing: Bool { editing != nil }

    private var previewPhoto: UIImage? {
        if removePhoto { return nil }
        return draftPhoto ?? editing?.photoImage
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                photoBlock

                HStack(spacing: 14) {
                    Button { showIconPicker = true } label: {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.accentSoft)
                            .frame(width: 52, height: 52)
                            .overlay(
                                Image(systemName: iconName)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                            )
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel("选择图标")

                    TextField(
                        "",
                        text: $name,
                        prompt: Text("例如 iPhone").foregroundStyle(Theme.placeholder)
                    )
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .fieldBox()
                }

                TextField(
                    "",
                    text: $summary,
                    prompt: Text("简介（可选）").foregroundStyle(Theme.placeholder),
                    axis: .vertical
                )
                .lineLimit(2...4)
                .foregroundStyle(Theme.ink)
                .fieldBox()

                MoneyField(title: "价值（元）", text: $priceText)

                VStack(alignment: .leading, spacing: 10) {
                    FieldLabel(text: "资产类型")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(AssetKind.allCases) { k in
                            Button {
                                withAnimation(.easeOut(duration: 0.16)) { kind = k }
                            } label: {
                                Text(k.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundStyle(kind == k ? Color.white : Theme.inkSoft)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(kind == k ? Theme.accent : Theme.paperDeep)
                                    )
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    Text(kind.hint)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                VStack(alignment: .leading, spacing: 10) {
                    FieldLabel(text: "已用次数（可选）")
                    TextField("0", text: $useCountText)
                        .keyboardType(.numberPad)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .fieldBox()
                        .onChange(of: useCountText) { _, new in
                            let digits = new.filter(\.isNumber)
                            if digits != new { useCountText = digits }
                        }
                    Text("用来算「单次成本」和「平均几天用一次」。平时点详情里的「用了一次」即可累加。")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                if kind.tracksStock {
                    VStack(alignment: .leading, spacing: 10) {
                        FieldLabel(text: "存量体感")
                        HStack(spacing: 8) {
                            ForEach(AssetStockStatus.allCases) { s in
                                Button {
                                    withAnimation(.easeOut(duration: 0.16)) { status = s }
                                } label: {
                                    Text(s.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .foregroundStyle(status == s ? Color.white : Theme.inkSoft)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(status == s ? Theme.accent : Theme.paperDeep)
                                        )
                                }
                                .buttonStyle(PressScaleButtonStyle())
                            }
                        }
                        Text(status.hint)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }

                SoftPanel(padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $setAcquiredAt.animation(.easeOut(duration: 0.16))) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("填写入手时间")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Theme.ink)
                                Text("用来算闲置多久、平均几天用一次。不填则用今天。")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .tint(Theme.accent)

                        if setAcquiredAt {
                            DatePicker(
                                "入手时间",
                                selection: $acquiredAt,
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                        }
                    }
                }

                Toggle(isOn: $isPublic) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("在个人主页公开")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.ink)
                        Text("打开后会出现在你的用户主页「资产」里")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .tint(Theme.accent)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surface)
                )
            }
            .padding(20)
            .padding(.bottom, 88)
        }
        .background(AtmosphereBackground())
        .navigationTitle(isEditing ? "编辑资产" : "登记资产")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }.foregroundStyle(Theme.inkSoft)
            }
        }
        .safeAreaInset(edge: .bottom) {
            SheetBottomBar(title: "保存", enabled: canSave, action: save)
        }
        .sheet(isPresented: $showIconPicker) {
            NavigationStack {
                IconPickerSheet(symbol: $iconName)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLibrary) {
            PhotoLibraryPicker(image: Binding(
                get: { draftPhoto },
                set: { new in
                    if let new {
                        draftPhoto = new
                        removePhoto = false
                    }
                }
            ))
            .ignoresSafeArea()
        }
        .onAppear { loadIfNeeded() }
    }

    private var photoBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel(text: "照片（可选）")
            Button { showLibrary = true } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.paperDeep)
                        .frame(height: 160)

                    if let previewPhoto {
                        Image(uiImage: previewPhoto)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                            Text("添加照片")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                }
            }
            .buttonStyle(PressScaleButtonStyle(pressedScale: 0.98))

            if previewPhoto != nil {
                Button("移除照片") {
                    draftPhoto = nil
                    removePhoto = true
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.warn)
            }
        }
    }

    private func loadIfNeeded() {
        guard let item = editing else { return }
        name = item.name
        summary = item.summary
        priceText = item.price > 0 ? String(format: "%g", item.price) : ""
        useCountText = "\(item.useCount)"
        kind = item.kind
        status = item.status
        iconName = item.resolvedIcon
        isPublic = item.isPublic
        acquiredAt = item.purchasedAt
        setAcquiredAt = true
        draftPhoto = nil
        removePhoto = false
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let when = setAcquiredAt ? acquiredAt : (editing?.purchasedAt ?? .now)
        if let item = editing {
            item.name = trimmed
            item.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            item.price = price
            item.useCount = max(0, useCount)
            item.kind = kind
            item.status = kind.tracksStock ? status : .plenty
            item.iconName = iconName
            item.isPublic = isPublic
            item.purchasedAt = when
            if useCount > 0 { item.lastUsedAt = item.lastUsedAt ?? .now }
            applyPhoto(to: item)
            ModelSave.commit(modelContext, successMessage: "资产已更新")
        } else {
            let item = AssetItem(
                name: trimmed,
                summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                price: price,
                useCount: max(0, useCount),
                status: kind.tracksStock ? status : .plenty,
                kind: kind,
                iconName: iconName,
                isPublic: isPublic,
                purchasedAt: when,
                lastUsedAt: useCount > 0 ? .now : nil
            )
            modelContext.insert(item)
            applyPhoto(to: item)
            ModelSave.commit(modelContext, successMessage: "资产已登记")
        }
        dismiss()
    }

    private func applyPhoto(to item: AssetItem) {
        if removePhoto {
            item.setPhoto(nil)
        } else if let draftPhoto {
            item.setPhoto(draftPhoto)
        }
    }
}

struct IconPickerSheet: View {
    @Binding var symbol: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            IconGridPicker(symbol: $symbol)
                .padding(20)
        }
        .background(AtmosphereBackground())
        .navigationTitle("选择图标")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}
