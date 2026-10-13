import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var gender: ProfileGender = .private_
    @State private var showLibrary = false
    @State private var draftAvatar: UIImage?
    @State private var clearAvatar = false

    private var previewImage: UIImage? {
        if clearAvatar { return nil }
        return draftAvatar ?? settings.avatarImage
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Button { showLibrary = true } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let image = previewImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Text(avatarInitial)
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Theme.accent)
                            }
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())

                        Image(systemName: "camera.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Circle().fill(Theme.accentDeep))
                    }
                }
                .buttonStyle(.plain)

                Text("点击头像更换，保存后生效")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)

                VStack(alignment: .leading, spacing: 10) {
                    FieldLabel(text: "昵称")
                    TextField(
                        "",
                        text: $name,
                        prompt: Text("点此输入昵称").foregroundStyle(Theme.placeholder)
                    )
                    .foregroundStyle(Theme.ink)
                    .fieldBox()
                }

                VStack(alignment: .leading, spacing: 10) {
                    FieldLabel(text: "性别")
                    HStack(spacing: 8) {
                        ForEach(ProfileGender.allCases) { g in
                            Button {
                                withAnimation(.easeOut(duration: 0.16)) { gender = g }
                            } label: {
                                Text(g.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundStyle(gender == g ? Color.white : Theme.inkSoft)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(gender == g ? Theme.accent : Theme.paperDeep)
                                    )
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    Text("选「不公开」时，主页不会展示性别。")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(20)
        }
        .background(AtmosphereBackground())
        .navigationTitle("编辑资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { commit() }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.accent)
            }
        }
        .onAppear {
            name = settings.nickname
            gender = settings.gender
            draftAvatar = nil
            clearAvatar = false
        }
        .sheet(isPresented: $showLibrary) {
            PhotoLibraryPicker(image: Binding(
                get: { draftAvatar },
                set: { new in
                    if let new {
                        draftAvatar = new
                        clearAvatar = false
                    }
                }
            ))
            .ignoresSafeArea()
        }
    }

    private var avatarInitial: String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { return String(n.prefix(1)) }
        return settings.avatarInitial
    }

    private func commit() {
        settings.nickname = name.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.gender = gender
        if clearAvatar {
            settings.clearAvatar()
        } else if let draftAvatar {
            settings.saveAvatar(draftAvatar)
        }
        SaveFeedback.post(message: "资料已保存")
        dismiss()
    }
}
