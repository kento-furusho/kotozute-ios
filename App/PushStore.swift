import Foundation
import Observation
import UIKit
import UserNotifications

/// 通知の許可と、端末トークンの受け取りを引き受ける。
///
/// トークンは OS から非同期に降ってくる。サインインより先に来ることもあるので、
/// ここでは受け取って持っておくだけにして、サーバーへ送るのは
/// `KotozuteStore.syncPushToken()` の側に任せる。
@Observable
@MainActor
final class PushStore {
    /// UIKit が AppDelegate を作るので、そこから書き込めるよう1つに決めておく。
    static let shared = PushStore()

    /// APNs から受け取った端末トークン（16進文字列）。まだ来ていなければ nil。
    private(set) var deviceToken: String?
    /// いま許可されているか。設定アプリで後から切られることもあるので、都度読み直す。
    private(set) var isAuthorized = false
    /// 一度でも許可を尋ねたか。二度目からは OS がダイアログを出さないので、
    /// 断られた場合は設定アプリへ案内する。
    private(set) var hasAsked = false

    private init() {}

    /// 現在の許可状態を OS に問い合わせて取り込む。
    func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
        hasAsked = settings.authorizationStatus != .notDetermined
        if isAuthorized {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// 許可を求める。許可されたら APNs への登録まで進める。
    ///
    /// 断られても呼び出し側は何もしない。オープンの通知は無くても
    /// アプリは成り立つし、催促にしたくない。
    @discardableResult
    func requestAuthorization() async -> Bool {
        hasAsked = true
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        isAuthorized = granted
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return granted
    }

    /// AppDelegate から呼ばれる。
    func received(deviceToken data: Data) {
        deviceToken = data.map { String(format: "%02x", $0) }.joined()
    }
}

/// APNs のトークンは UIApplicationDelegate 経由でしか受け取れないので、
/// SwiftUI の App に相乗りさせる。
final class PushAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in PushStore.shared.received(deviceToken: deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        // 通知が使えないだけで、アプリは動く。落とさずログに残す。
        print("APNs への登録に失敗した: \(error.localizedDescription)")
    }
}
