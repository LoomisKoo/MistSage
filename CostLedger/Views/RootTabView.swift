import SwiftUI

struct RootTabView: View {
    @StateObject private var settings = AppSettings.shared
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            TabView {
                PlazaListView()
                    .tabItem { Label("广场", systemImage: "square.grid.2x2.fill") }

                DecisionHubView()
                    .tabItem { Label("决策", systemImage: "checklist") }

                AssetListView()
                    .tabItem { Label("资产", systemImage: "shippingbox.fill") }

                MineView()
                    .tabItem { Label("我的", systemImage: "person.crop.circle.fill") }
            }
            .tint(Theme.accent)
            .floatingPlus { showCreate = true }
            .sheet(isPresented: $showCreate) {
                CreateChoiceSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .environmentObject(settings)
        .saveToast()
    }
}

/// 导航栏加号：整圆可点
struct ToolbarPlusButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

/// 右下角悬浮加号
struct FloatingPlusButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Theme.accent))
                .shadow(color: Theme.accent.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("添加")
    }
}

extension View {
    /// 列表页右下角悬浮 +
    func floatingPlus(action: @escaping () -> Void) -> some View {
        overlay(alignment: .bottomTrailing) {
            FloatingPlusButton(action: action)
                .padding(.trailing, 20)
                // 抬高，避免压住右侧「我的」Tab
                .padding(.bottom, 64)
        }
    }
}
