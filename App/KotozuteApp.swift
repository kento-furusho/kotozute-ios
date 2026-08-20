import SwiftUI

@main
struct KotozuteApp: App {
    /// APNs のトークンは UIApplicationDelegate 経由でしか受け取れない。
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var pushDelegate

    @State private var auth: AuthStore?
    @State private var setupError: String?
    /// 招待は未サインインでも扱うので、認証の外側に置く。
    @State private var router = InviteRouter()

    /// シミュレータでの確認用。オンボーディングは通常サインアウトしないと見られない。
    ///   xcrun simctl launch <udid> dev.kotozute.app --screen welcome|concept
    @ViewBuilder
    private static var previewScreen: (some View)? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--screen"), index + 1 < arguments.count {
            switch arguments[index + 1] {
            case "welcome": WelcomeView(onStart: {}, onSignIn: {})
            case "concept": ConceptView(onDone: {})
            case "exchange": ConceptView(onDone: {}, startPage: 1)
            default: nil as EmptyView?
            }
        } else {
            nil as EmptyView?
        }
        #else
        nil as EmptyView?
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let screen = Self.previewScreen {
                    screen
                } else if let auth {
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
