import SwiftUI
import SwiftData

enum SaveFeedback {
    static let didSave = Notification.Name("CostLedgerDidSave")

    static func post(message: String) {
        NotificationCenter.default.post(
            name: didSave,
            object: nil,
            userInfo: ["message": message]
        )
    }
}

struct SaveToastBanner: ViewModifier {
    @State private var message: String?
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if visible, let message {
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Theme.accentDeep))
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: SaveFeedback.didSave)) { note in
                message = note.userInfo?["message"] as? String ?? "已保存"
                withAnimation(.easeOut(duration: 0.2)) { visible = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(.easeIn(duration: 0.2)) { visible = false }
                }
            }
    }
}

extension View {
    func saveToast() -> some View { modifier(SaveToastBanner()) }
}

enum ModelSave {
    static func commit(_ context: ModelContext, successMessage: String) {
        do {
            try context.save()
            SaveFeedback.post(message: successMessage)
        } catch {
            SaveFeedback.post(message: "保存失败，请重试")
        }
    }
}
