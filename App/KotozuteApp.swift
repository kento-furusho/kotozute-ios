import SwiftUI

@main
struct KotozuteApp: App {
    @State private var auth: AuthStore?
    @State private var setupError: String?
    /// 招待は未サインインでも扱うので、認証の外側に置く。
    @State private var router = InviteRouter()

    var body: some Scene {
        WindowGroup {
            Group {
                if let auth {
                    RootView(auth: auth, router: router)
                } else if let setupError {
                    Text(setupError)
                        .font(Theme.font(15))
                        .foregroundStyle(Theme.ink)
                        .padding(28)
                } else {
                    ProgressView()
                }
            }
            .tint(Theme.accent)
            // 招待リンク（kotozute://invite/<token>）で起動されたとき。
            .onOpenURL { router.open(url: $0) }
            .task {
                router.seedFromLaunchArguments()
                guard auth == nil, setupError == nil else { return }
                do {
                    auth = try AuthStore()
                } catch {
                    setupError = "認証の準備に失敗した。\(error.localizedDescription)"
                }
            }
        }
    }
}
