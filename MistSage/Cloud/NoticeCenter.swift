import SwiftUI
import SwiftData
@preconcurrency import UserNotifications

/// 通知：冷静期结束的本地提醒 + 别人互动时的 CloudKit 推送
@MainActor
final class NoticeCenter: ObservableObject {
    static let shared = NoticeCenter()

    @Published private(set) var status: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    private init() {}

    var isAuthorized: Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    func refreshStatus() async {
        status = await center.notificationSettings().authorizationStatus
    }

    /// 已授权时注册远程推送并确保订阅存在
    func refreshRegistration() async {
        await refreshStatus()
        guard isAuthorized else { return }
        UIApplication.shared.registerForRemoteNotifications()
        await CloudSync.shared.ensureNoticeSubscriptions()
    }

    /// 在用户刚发布或刚提建议时再问，系统弹窗只会出现一次
    func requestIfNeeded() async {
        await refreshStatus()
        guard status == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refreshRegistration()
    }

    // MARK: - 冷静期提醒

    static func scheduleCoolingReminder(for review: ReviewRequest) {
        guard review.status == .cooling, let coolUntil = review.coolUntil, coolUntil > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = L("冷静期结束了")
        content.body = L("「\(review.title)」现在可以再想想，要不要做决定。")
        content.sound = .default
        content.userInfo = ["review": review.recordName]

        let interval = max(1, coolUntil.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: coolingID(review), content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelCoolingReminder(for review: ReviewRequest) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [coolingID(review)])
    }

    static func cancelAllCoolingReminders() {
        Task {
            let center = UNUserNotificationCenter.current()
            let ids = await center.pendingNotificationRequests()
                .map(\.identifier)
                .filter { $0.hasPrefix("cool_") }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private static func coolingID(_ review: ReviewRequest) -> String {
        "cool_\(review.recordName)"
    }
}

extension ModelContext {
    /// 记一条待发通知，下次同步时上传；不给自己发
    func enqueueNotice(to recipientID: String, kind: NoticeKind, review: ReviewRequest) {
        guard !recipientID.isEmpty, recipientID != AccountSession.currentUserID else { return }
        insert(OutgoingNotice(
            recipientID: recipientID,
            kind: kind,
            reviewID: review.recordName,
            reviewTitle: review.title
        ))
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// 用回调版本：async 版本要把非 Sendable 的 userInfo 跨隔离传入
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task {
            await CloudSync.shared.syncNow()
            completionHandler(.newData)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        Task { @MainActor in await CloudSync.shared.syncNow() }
        return [.banner, .sound]
    }
}
