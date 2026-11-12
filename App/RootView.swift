import KotozuteAPI
import SwiftUI

/// 認証の状態で入口を分ける。サインイン後は GET /me を起点に画面を決める。
struct RootView: View {
    @Bindable var auth: AuthStore
    @Bindable var router: InviteRouter
    /// 招待を見たあと、サインイン／登録へ進んだか。
    @State private var didContinueFromInvite = false
    /// はじめる画面を抜けたか。抜けた先が登録かサインインかも覚えておく。
    @State private var entry: Entry?

    private enum Entry {
        case register
        case signIn
    }

    var body: some View {
        Group {
            switch auth.phase {
            case .checking:
                loading
            case .signedOut, .needsConfirmation:
                // 招待リンクから来た未サインインの相手には、まず「誰からか」を見せる。
                if router.pendingToken != nil, !didContinueFromInvite {
                    InviteLandingView(router: router) {
                        didContinueFromInvite = true
                        // 招待から来た人は「誰からの招待か」で惹きつけ済み。
                        // 説明を挟まず登録へ渡す（される側は別導線）。
                        entry = .register
                    }
                } else if case let .needsConfirmation(email) = auth.phase {
                    ConfirmView(auth: auth, email: email)
                } else if let entry {
                    AuthView(auth: auth, startsRegistering: entry == .register)
                } else {
                    // 説明を全部見せてから登録へ渡す。登録の前に「何のアプリか」が
                    // 分かっている状態を作る。
                    OnboardingView(
                        onStart: { entry = .register },
                        onSignIn: { entry = .signIn }
                    )
                }
            case .signedIn:
                // サインインし直したら作り直したいので、認証済みかどうかを id にする。
                SignedInView(auth: auth, router: router)
                    .id("signed-in")
            }
        }
        .task { await auth.restore() }
        .onChange(of: auth.phase) { _, new in
            // サインアウトしたら、招待の見せ方を最初からやり直す。
            if new == .signedOut, router.pendingToken == nil {
                didContinueFromInvite = false
                entry = nil
            }
        }
    }

    private var loading: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
    }
}

/// サインイン済みの中身。API の状態で出し分ける。
struct SignedInView: View {
    @Bindable var auth: AuthStore
    @Bindable var router: InviteRouter
    @State private var store: KotozuteStore
    @State private var wall: WallStore
    @State private var calendar: CalendarStore
    /// 最初の1枚の画面を通過したか。書いたかどうかではなく「通ったか」で判断する
    /// （「あとで」を選んだ人を毎回そこへ戻さないため）。
    /// ペア未成立のままホームを見ている。招待画面と行き来する。
    @State private var showsHomeWithoutPair = false
    @AppStorage("hasPassedFirstKotozute") private var hasPassedFirstKotozute = false
    /// 招待画面から一度ホームへ出たか。出たあとに設定の「ペアを組む」から来たときは、
    /// 登録直後の流れではないので、何枚目かの点を出さない。
    @AppStorage("hasLeftOnboarding") private var hasLeftOnboarding = false

    init(auth: AuthStore, router: InviteRouter) {
        self.auth = auth
        self.router = router
        // TokenProvider に認証層をそのまま渡す。API クライアントは
        // トークンの取得元が Cognito であることを知らない。
        let client = KotozuteClient(
            baseURL: Config.apiBaseURL,
            tokenProvider: auth.authenticator
        )
        _store = State(initialValue: KotozuteStore(client: client))
        _wall = State(initialValue: WallStore(client: client))
        _calendar = State(initialValue: CalendarStore(client: client))
    }

    var body: some View {
        Group {
            switch store.phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background.ignoresSafeArea())
            case .needsProfile:
                // 登録直後の人だけがここを通る。説明は登録の前に済ませてあるので、
                // ここでは名前を聞くだけ。
                ProfileSetupView(store: store)
            case .noPair:
                // 招待を抱えていれば受諾へ。
                if router.pendingToken != nil {
                    AcceptInviteView(router: router, store: store)
                } else if !hasPassedFirstKotozute {
                    // 招待より先に「書く」を一度体験してもらう。
                    FirstKotozuteView(store: store) { hasPassedFirstKotozute = true }
                } else if showsHomeWithoutPair {
                    // 相手を待つあいだもアプリを使える。ことづてはペア未成立でも
                    // 書けるので、招待画面で足止めしない。
                    MainTabView(store: store, auth: auth, wall: wall, calendar: calendar) {
                        showsHomeWithoutPair = false
                    }
                } else {
                    InviteView(store: store, auth: auth, router: router, showsSteps: !hasLeftOnboarding) {
                        hasLeftOnboarding = true
                        showsHomeWithoutPair = true
                    }
                }
            case .ready:
                MainTabView(store: store, auth: auth, wall: wall, calendar: calendar)
            case let .failed(message):
                errorView(message)
            }
        }
        .task { await store.load() }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .font(Theme.font(15))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Button("もう一度") {
                Task { await store.load() }
            }
            .font(Theme.font(16, weight: .bold))
            .foregroundStyle(Theme.accent)
            Button("サインアウト") {
                Task {
                    await store.releasePushToken()
                    await auth.signOut()
                }
            }
            .font(Theme.font(14))
            .foregroundStyle(Theme.inkSoft)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}

/// Cognito の登録は済んだが、表示名がまだのとき（POST /users）。登録直後の3枚の1枚目。
///
/// 以前は見出しと入力欄だけで、何に使う名前なのかが書かれていなかった。
/// 入力例も開発者の名前（「けんと」）で、ほかの人には意味が通じなかった。
struct ProfileSetupView: View {
    @Bindable var store: KotozuteStore
    @State private var displayName = ""
    @State private var isSubmitting = false
    @FocusState private var isFocused: Bool

    /// サーバーの上限（post-users の maxDisplayNameRunes）と同じ。
    private static let maxLength = 20

    var body: some View {
        VStack(spacing: 0) {
            OnboardingSteps(current: 0)
                .padding(.top, 20)

            Text("ニックネーム")
                .font(Theme.font(26, weight: .bold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 48)

            Text("ペアの相手の画面に表示される名前です。\nあとから設定で変更できます。")
                .font(Theme.font(15))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 10)

            TextField("たろう", text: $displayName)
                .font(Theme.font(17))
                .padding(14)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                .focused($isFocused)
                .submitLabel(.next)
                .onSubmit(submit)
                .padding(.top, 28)

            if isTooLong {
                Text("\(Self.maxLength)文字以内で入力してください。")
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }

            Button(action: submit) {
                Group {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("すすむ").font(Theme.font(17, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSubmit ? Theme.accent : Theme.inkSoft.opacity(0.4))
                .clipShape(Capsule())
            }
            .disabled(!canSubmit || isSubmitting)
            .padding(.top, 24)

            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        // 入れるものが1つしかない画面なので、開いたらすぐ打てるようにする。
        .onAppear { isFocused = true }
    }

    private var trimmed: String { displayName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isTooLong: Bool { trimmed.count > Self.maxLength }
    private var canSubmit: Bool { !trimmed.isEmpty && !isTooLong }

    private func submit() {
        guard canSubmit, !isSubmitting else { return }
        Task {
            isSubmitting = true
            await store.registerProfile(displayName: trimmed)
            isSubmitting = false
        }
    }
}

/// ペア未成立のとき。オンボーディングの締めで、相手を誘う画面。登録直後の3枚の3枚目。
/// 設定の「ペアを組む」からも来る。
///
/// 以前はボタンが4つ縦に並び（リンクを送る／ことづてを書く／招待をもらっている／ホームに戻る）、
/// どれを押せばいいのか迷った。いちばんしてほしいこと（リンクを送る）だけを大きくし、
/// ほかは控えめにした。「ことづてを書く」は、直前の画面で書いたばかりなので外した
/// （ホームからいつでも書ける）。招待コードは長い英数字なので、ふだんは畳んでおく
/// （「リンクを送る」の文面にコードは入っている）。
struct InviteView: View {
    @Bindable var store: KotozuteStore
    @Bindable var auth: AuthStore
    @Bindable var router: InviteRouter
    /// 登録直後の流れで来たときだけ、何枚目かの点を出す（設定から来たときは出さない）。
    var showsSteps = false
    /// ペアを待たずにアプリへ入る。
    var onHome: () -> Void = {}
    @State private var enteredCode = ""
    @State private var showsCodeEntry = false
    @State private var showsMyCode = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if showsSteps {
                    OnboardingSteps(current: 2)
                        .padding(.top, 20)
                }

                Text("ふたりではじめる")
                    .font(Theme.font(26, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, showsSteps ? 32 : 48)

                Text("リンクを送れば、それだけで始められます。")
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 10)

                firstNote

                if let token = store.inviteToken {
                    ShareLink(item: Self.message(token: token)) {
                        Label("リンクを送る", systemImage: "square.and.arrow.up")
                            .font(Theme.font(17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.accent)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 32)

                    Text("LINE やメッセージで送れます。")
                        .font(Theme.font(13))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.top, 8)

                    myCode(token)
                } else {
                    ProgressView()
                        .padding(.top, 48)
                }

                codeEntry
                    .padding(.top, 36)

                // 相手が受けるのを待たずにアプリを使える。ことづてはペア未成立でも
                // 書けるので、この画面で足止めする理由が無い。
                // サインアウトはここには置かない（設定にある。戻れなくなるほうが困る）。
                VStack(spacing: 8) {
                    Text("相手を待つあいだも、ことづては書きためられます。")
                        .font(Theme.font(13))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                    Button("あとで送る") { onHome() }
                        .font(Theme.font(15, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.vertical, 6)
                }
                .padding(.top, 36)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        // 開いた時点でリンクを用意しておく。誘うのが目的の画面なので、
        // 「つくる」を挟まずそのまま送れるようにする。
        // 開くたび・アプリに戻るたびに確かめる。何日も開きっぱなしにしていると、
        // 期限の切れたリンクを送ってしまう。
        .task { await store.ensureFreshInvite() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.ensureFreshInvite() } }
        }
    }

    /// 自分の招待コード。ふだんは畳む（送る文面に入っているので、見る必要がある人は少ない）。
    @ViewBuilder
    private func myCode(_ token: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { showsMyCode.toggle() }
        } label: {
            HStack(spacing: 4) {
                Text(showsMyCode ? "招待コードを隠す" : "招待コードを表示")
                Image(systemName: showsMyCode ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .font(Theme.font(13))
            .foregroundStyle(Theme.inkSoft)
        }
        .padding(.top, 16)

        if showsMyCode {
            Text(token)
                .font(Theme.font(13, weight: .medium))
                .foregroundStyle(Theme.ink)
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                .padding(.top, 8)

            Text("長押しでコピーできます。")
                .font(Theme.font(12))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 6)
        }
    }

    /// 相手から招待を受け取った人の入口。
    @ViewBuilder
    private var codeEntry: some View {
        VStack(spacing: 0) {
            Button(showsCodeEntry ? "閉じる" : "招待をもらっている") {
                withAnimation(.easeInOut(duration: 0.18)) { showsCodeEntry.toggle() }
            }
            .buttonStyle(OutlineButtonStyle())

            if showsCodeEntry {
                HStack(spacing: 10) {
                    TextField("招待コード", text: $enteredCode)
                        .font(Theme.font(15))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))

                    Button("すすむ") { router.accept(token: enteredCode.trimmingCharacters(in: .whitespacesAndNewlines)) }
                        .font(Theme.font(15, weight: .bold))
                        .foregroundStyle(enteredCode.isEmpty ? Theme.inkSoft : Theme.accent)
                        .disabled(enteredCode.isEmpty)
                }
                .padding(.top, 12)
            }
        }
    }

    /// もう書いてある1枚目。「送れば、これがふたりの壁になる」を目に見える形にする。
    /// デザイン案（初回導線B ⑤）はここに1枚目を置いている。
    @ViewBuilder
    private var firstNote: some View {
        // createdAt で決める。配列の順序に頼ると、並びが変わったとき静かにずれる。
        if let first = store.myKotozute.min(by: { $0.createdAt < $1.createdAt }) {
            VStack(spacing: 10) {
                Text("1枚目のことづて")
                    .font(Theme.font(12, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)

                StickyNote(kotozute: first, paper: first.color.flatMap(Theme.stickyPaper(hex:)) ?? Theme.stickyPaper(at: 0), tilt: -2)
                    .frame(width: 208)
            }
            .padding(.top, 28)
        }
    }

    /// リンクとコードの両方を載せる。独自スキームのリンクは
    /// アプリによっては押せないので、コードだけでも受け取れるようにする。
    /// 「リンクを送る」で LINE などに貼られる文。
    ///
    /// **送る本人の言葉で、ていねいに。** 以前は「ことづてに誘われている。」で始まっていて、
    /// 受け取った側の言い方だった（送り主が「私が誘われている」と言っているように読める）。
    ///
    /// **App Store のリンクを入れる。** 相手はまだアプリを持っていない。
    /// 以前は kotozute:// のリンクだけで、LINE やメッセージでは押せる形にならず、
    /// アプリが無い人が押しても何も起きなかった。入手先も書いていなかった。
    private static func message(token: String) -> String {
        """
        「ことづて」というアプリで、ありがとうを送り合いませんか？
        こちらからダウンロードできます。
        \(Config.appStoreURL.absoluteString)

        登録したら「招待をもらっている」から、このコードを入れてください。
        \(token)
        """
    }
}
