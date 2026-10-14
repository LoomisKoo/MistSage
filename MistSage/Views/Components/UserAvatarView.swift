import SwiftUI

/// 头像：按用户 ID 从用户表缓存取；没有头像时用昵称首字色块
struct UserAvatarView: View {
    let userID: String
    var size: CGFloat = 40
    @ObservedObject private var users = UserDirectory.shared
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Group {
            if let image = users.avatar(for: userID) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(initial)
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(fillColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var name: String { users.name(for: userID) }

    private var initial: String {
        String((name.isEmpty ? "?" : name).prefix(1))
    }

    private var fillColor: Color {
        if users.isMe(userID) { return Theme.accent }
        let palette: [Color] = [
            Theme.accent,
            Theme.accentDeep,
            Color(red: 0.40, green: 0.55, blue: 0.75),
            Color(red: 0.45, green: 0.62, blue: 0.58),
            Color(red: 0.55, green: 0.48, blue: 0.70),
        ]
        let idx = userID.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % palette.count
        return palette[abs(idx)]
    }
}
