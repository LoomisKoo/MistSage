import SwiftUI
import SwiftData

@main
struct MistSageApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 尽早套用 App 内语言，之后取到的文案才是所选语言
        _ = AppSettings.shared
        container = Self.makeContainer()
        Self.configureNavigationBar()
    }

    /// iOS 26 起系统导航栏自带液态玻璃，保持默认；更早版本始终显示毛玻璃（含滚动到顶部时）
    private static func configureNavigationBar() {
        if #available(iOS 26, *) { return }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = .clear
        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        bar.compactScrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .tint(Theme.accent)
                .task {
                    CloudSync.shared.start(context: container.mainContext)
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await CloudSync.shared.refreshOnForeground() }
            }
        }
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([
            DecisionRecord.self,
            AssetItem.self,
            ReviewRequest.self,
            ReviewVote.self,
            UserProfile.self,
            PendingDeletion.self,
            BlockEntry.self,
            OutgoingNotice.self,
        ])
        // 接入云端后本地只是缓存；旧版本本地库不再迁移，换名后从云端重新拉
        let storeName = "MistSage_v3"
        let config = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // 本地只是云端缓存，结构变了直接清掉重建
            Self.resetPersistentStores()
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("SwiftData 重建仍失败: \(error)")
            }
        }
    }

    private static func resetPersistentStores() {
        let fm = FileManager.default
        guard let appSupport = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ),
        let contents = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil)
        else { return }

        for url in contents where url.lastPathComponent.contains(".store") {
            try? fm.removeItem(at: url)
        }
    }
}
