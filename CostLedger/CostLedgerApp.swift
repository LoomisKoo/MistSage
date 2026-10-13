import SwiftUI
import SwiftData

@main
struct CostLedgerApp: App {
    private let container: ModelContainer

    init() {
        container = Self.makeContainer()
        PlazaSeed.bootstrapIfNeeded(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.light)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([
            DecisionRecord.self,
            AssetItem.self,
            ReviewRequest.self,
            ReviewVote.self,
        ])
        let storeName = "CostLedger_v3"
        let config = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // 模型字段变更后旧库无法迁移时，清库重建（开发期可接受）
            Self.resetPersistentStore(named: storeName)
            Self.resetPersistentStore(named: "CostLedger")
            PlazaSeed.resetFlags()
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("SwiftData 重建仍失败: \(error)")
            }
        }
    }

    private static func resetPersistentStore(named name: String) {
        let fm = FileManager.default
        guard let appSupport = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return }

        let candidates = [
            appSupport.appendingPathComponent("\(name).store"),
            appSupport.appendingPathComponent("\(name).store-shm"),
            appSupport.appendingPathComponent("\(name).store-wal"),
            appSupport.appendingPathComponent("default.store"),
            appSupport.appendingPathComponent("default.store-shm"),
            appSupport.appendingPathComponent("default.store-wal"),
        ]

        for url in candidates {
            try? fm.removeItem(at: url)
        }

        // 兼容未命名配置时的默认路径
        if let contents = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
            for url in contents where url.lastPathComponent.contains(".store") {
                try? fm.removeItem(at: url)
            }
        }
    }
}
