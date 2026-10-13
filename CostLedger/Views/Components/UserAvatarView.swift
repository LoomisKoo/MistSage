import SwiftUI

/// 头像：本人用真实头像，其他人用昵称首字色块
struct UserAvatarView: View {
    let name: String
    var isMe: Bool = false
    var size: CGFloat = 40
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Group {
            if isMe, let image = settings.avatarImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(initial)
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .background(Circle().fill(isMe && settings.avatarImage != nil ? Color.clear : fillColor))
        .clipShape(Circle())
    }

    private var initial: String {
        let n = isMe ? settings.displayName : name
        return String((n.isEmpty ? "?" : n).prefix(1))
    }

    private var fillColor: Color {
        if isMe { return Theme.accent }
        let palette: [Color] = [
            Theme.accent,
            Theme.accentDeep,
            Color(red: 0.40, green: 0.55, blue: 0.75),
            Color(red: 0.45, green: 0.62, blue: 0.58),
            Color(red: 0.55, green: 0.48, blue: 0.70),
        ]
        let idx = abs(name.hashValue) % palette.count
        return palette[idx]
    }
}
