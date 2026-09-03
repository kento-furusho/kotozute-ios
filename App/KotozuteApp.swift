import KotozuteAPI
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
    ///
    /// 確認用の画面を直接開く。指定が無ければ nil を返し、通常の起動に任せる。
    ///
    /// @ViewBuilder は使わない。分岐を包んだ結果が「中身が空の非 nil」になり、
    /// 引数なしの通常起動でも `if let` が成立して真っ白な画面になる。
    /// AnyView で受けて、返さないときは明示的に nil を返す。
    ///
    ///   xcrun simctl launch <udid> dev.kotozute.app --screen welcome|concept|auth|signin|viewing|reveal|detail|invite|invite-landing
    private static var previewScreen: AnyView? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--screen"), index + 1 < arguments.count else {
            return nil
        }
        let screen = arguments[index + 1]
        switch screen {
        case "welcome":
            return AnyView(OnboardingView(onStart: {}, onSignIn: {}))
        case "concept":
            return AnyView(OnboardingView(onStart: {}, onSignIn: {}, startPage: 1))
        // 登録画面。ふだんはオンボーディングから「はじめる」を押さないと出ない。
        case "auth", "signin":
            guard let auth = try? AuthStore() else { return nil }
            return AnyView(AuthView(auth: auth, startsRegistering: screen == "auth"))
        // オープンの演出。本物と同じく fullScreenCover の中に出す。
        // 直に置くと dismiss() の相手がおらず、「とじる」も「1枚ずつ読む」も効かない。
        case "reveal":
            return AnyView(RevealPreviewHost())
        // 1枚ずつ読む画面。自分の分（書き直せる）として開く。
        case "detail":
            return AnyView(
                KotozuteDetailView(
                    detail: KotozuteDetail(
                        items: [
                            Kotozute(id: "d1", body: "急いでたのに駅まで送ってくれた。ほんとうに助かった。", createdAt: Date()),
                            Kotozute(id: "d2", body: "洗い物、いつのまにか終わってた", createdAt: Date()),
                        ],
                        startIndex: 0,
                        title: "ひとりのことづて",
                        colorOffset: 0,
                        isEditable: true
                    )
                )
            )
        // 「見る」画面。4分岐あるうえ、実データでは相手に書いてもらわないと出せない。
        // --demo-state waiting|locked|visible と併せて使う。
        case "viewing":
            guard let auth = try? AuthStore() else { return nil }
            // ストアはデモ（client: nil）で、起動引数から状態を組む。
            // 壁のほうは実クライアントを渡すが、週の履歴は読めないので空のまま。
            // index は 0 で「いちばん新しい週」になるので、確認したい分岐はそこに出る。
            let client = KotozuteClient(baseURL: Config.apiBaseURL, tokenProvider: auth.authenticator)
            return AnyView(ViewingView(store: KotozuteStore(client: nil), wall: WallStore(client: client)))
        // 招待画面は「登録済み・ペア未成立」でないと出ないので確認しづらい。
        // --demo-state waiting と併せて使うと1枚目が入った状態で見られる。
        case "invite":
            guard let auth = try? AuthStore() else { return nil }
            return AnyView(
                InviteView(
                    store: KotozuteStore(client: nil),
                    auth: auth,
                    router: InviteRouter()
                )
            )
        // 招待される側の入口。--invite <token> と併せて使う。
        case "invite-landing":
            let router = InviteRouter()
            router.seedFromLaunchArguments()
            return AnyView(InviteLandingView(router: router) {})
        default:
            return nil
        }
        #else
        return nil
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

#if DEBUG
/// 確認用。演出を本物と同じ出し方（fullScreenCover）で見るための入れ物。
private struct RevealPreviewHost: View {
    @State private var isShowing = true

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 14) {
                Text("とじた")
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.inkSoft)
                Button("もう一度見る") { isShowing = true }
                    .font(Theme.font(15, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .fullScreenCover(isPresented: $isShowing) {
            RevealView(
                partnerName: "ゆい",
                items: [
                    Kotozute(id: "r1", body: "コーヒー淹れてくれてありがとう", createdAt: Date()),
                    Kotozute(id: "r2", body: "昨日の話、ちゃんと聞いてくれてうれしかった", createdAt: Date()),
                    Kotozute(id: "r3", body: "洗い物、いつのまにか終わってた", createdAt: Date()),
                ]
            ) {}
        }
    }
}
#endif
