import SwiftUI

enum RootTab: Hashable {
    case plaza, decisions, assets, mine

    var title: String {
        switch self {
        case .plaza: return L("广场")
        case .decisions: return L("决策")
        case .assets: return L("资产柜")
        case .mine: return L("我的")
        }
    }
}

/// 导航栈包在 TabView 外层：push 的页面会盖住底部 Tab 栏
struct RootTabView: View {
    @StateObject private var settings = AppSettings.shared
    @ObservedObject private var cloud = CloudSync.shared
    @State private var tab: RootTab = .plaza
    @State private var showCreate = false
    @State private var showICloudHint = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            TabView(selection: $tab) {
                PlazaListView()
                    .tabItem { Label("广场", systemImage: "square.grid.2x2.fill") }
                    .tag(RootTab.plaza)

                DecisionHubView()
                    .tabItem { Label("决策", systemImage: "checklist") }
                    .tag(RootTab.decisions)

                AssetListView()
                    .tabItem { Label("资产", systemImage: "shippingbox.fill") }
                    .tag(RootTab.assets)

                MineView()
                    .tabItem { Label("我的", systemImage: "person.crop.circle.fill") }
                    .tag(RootTab.mine)
            }
            .tint(Theme.accent)
            .floatingPlus {
                if cloud.canWrite {
                    showCreate = true
                } else {
                    showICloudHint = true
                }
            }
            // 标题由 principal 显示；这里设一份是为了让下一页的返回按钮用本地化文案，而不是系统的「Back」
            .navigationTitle(tab.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(tab.title)
                        .font(.system(.headline, design: .serif).weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
                if tab == .mine {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("设置")
                    }
                }
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
        }
        // 换语言后重建界面，让 L() 算出的文案也刷新；showSettings 保留，会停在设置页
        .id(settings.languageRaw)
        .sheet(isPresented: $showCreate) {
            CreateChoiceSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .iCloudRequiredAlert(isPresented: $showICloudHint)
        // 放在 sheet / alert 之后，弹出层才会继承所选语言
        .environment(\.locale, settings.language.locale)
        .environmentObject(settings)
        .preferredColorScheme(settings.preferredColorScheme)
        .saveToast()
    }
}

private struct ICloudRequiredAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    @ObservedObject private var cloud = CloudSync.shared

    func body(content: Content) -> some View {
        content.alert(title, isPresented: $isPresented) {
            if showsRetry {
                Button("重试") {
                    Task { await cloud.bootstrap() }
                }
            }
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("好", role: .cancel) {}
        } message: {
            Text(message)
        }
    }

    private var showsRetry: Bool {
        if case .noAccount = cloud.state { return false }
        return !AccountSession.isPendingDeletion
    }

    private var title: String {
        if AccountSession.isPendingDeletion { return L("账号正在注销") }
        switch cloud.state {
        case .noAccount: return L("需要登录 iCloud")
        case .checking: return L("正在连接 iCloud")
        default: return L("iCloud 暂时不可用")
        }
    }

    private var message: String {
        if AccountSession.isPendingDeletion {
            return L("云端数据还在清理中，完成后会自动创建新账号。请保持联网并稍后再试。")
        }
        switch cloud.state {
        case .noAccount:
            return L("记录、发帖和给建议需要 iCloud。请打开系统「设置」，点最上方登录 Apple 账户。未登录时仍可浏览广场。")
        case .checking:
            return L("正在识别你的 iCloud 账号，请稍等几秒再试。")
        case .unavailable(let reason):
            return L("""
            \(reason)

            请检查：
            1. 系统「设置」最上方的 Apple 账户是否提示需要验证或更新
            2. 设置 → Apple 账户 → iCloud → 显示全部，确认「MistSage」已打开
            3. 网络是否正常

            处理后回到 app 会自动重试，也可以点「重试」。
            """)
        case .available:
            return L("请稍后再试。")
        }
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
        .accessibilityLabel("发布")
    }
}

extension View {
    /// 不能写入时的提示：按 iCloud 状态告诉用户怎么恢复
    func iCloudRequiredAlert(isPresented: Binding<Bool>) -> some View {
        modifier(ICloudRequiredAlertModifier(isPresented: isPresented))
    }

    /// 列表页右下角悬浮 +
    func floatingPlus(action: @escaping () -> Void) -> some View {
        overlay(alignment: .bottomTrailing) {
            FloatingPlusButton(action: action)
                .padding(.trailing, 20)
                .padding(.bottom, 64)
        }
    }
}
