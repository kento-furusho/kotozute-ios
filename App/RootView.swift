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
    /// 最初の1枚の画面を通過したか。書いたかどうかではなく「通ったか」で判断する
    /// （「あとで」を選んだ人を毎回そこへ戻さないため）。
    /// ペア未成立のままホームを見ている。招待画面と行き来する。
    @State private var showsHomeWithoutPair = false
    @AppStorage("hasPassedFirstKotozute") private var hasPassedFirstKotozute = false

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
                    MainTabView(store: store, auth: auth, wall: wall) {
                        showsHomeWithoutPair = false
                    }
                } else {
                    InviteView(store: store, auth: auth, router: router) {
                        showsHomeWithoutPair = true
                    }
                }
            case .ready:
                MainTabView(store: store, auth: auth, wall: wall)
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
                Task { await auth.signOut() }
            }
            .font(Theme.font(14))
            .foregroundStyle(Theme.inkSoft)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}

/// Cognito の登録は済んだが、表示名がまだのとき（POST /users）。
struct ProfileSetupView: View {
    @Bindable var store: KotozuteStore
    @State private var displayName = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("ニックネーム")
                .font(Theme.font(26, weight: .bold))
                .foregroundStyle(Theme.ink)
            TextField("けんと", text: $displayName)
                .font(Theme.font(16))
                .padding(14)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                .padding(.top, 28)

            Button("すすむ") {
                Task { await store.registerProfile(displayName: displayName) }
            }
            .font(Theme.font(17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(displayName.isEmpty ? Theme.inkSoft.opacity(0.4) : Theme.accent)
            .clipShape(Capsule())
            .disabled(displayName.isEmpty)
            .padding(.top, 24)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}

/// ペア未成立のとき。オンボーディングの締めで、相手を誘う画面。
struct InviteView: View {
    @Bindable var store: KotozuteStore
    @Bindable var auth: AuthStore
    @Bindable var router: InviteRouter
    /// ペアを待たずにアプリへ入る。
    var onHome: () -> Void = {}
    @State private var enteredCode = ""
    @State private var showsCodeEntry = false
    @State private var isWriting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("ふたりではじめる")
                    .font(Theme.font(26, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 48)

                Text("リンクを送れば、それだけではじまる。")
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 10)

                firstNote

                if let token = store.inviteToken {
                    ShareLink(item: Self.message(token: token)) {
                        Text("リンクを送る")
                            .font(Theme.font(17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.accent)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 36)

                    Text("招待コード")
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.top, 24)

                    Text(token)
                        .font(Theme.font(13, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                        .padding(.top, 6)

                    Text("長押しでコピーできる。")
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.top, 6)
                } else {
                    ProgressView()
                        .padding(.top, 48)
                }

                // 待っているあいだも書ける（ことづては書いた人の下に貯まる）。
                // 相手が来るまで何もできない、という時間にしない。
                Text("相手を待つあいだも、ことづては書きためられる。")
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.top, 36)

                if store.myKotozute.count > 1 {
                    StickyNoteList(items: Array(store.myKotozute.dropFirst()))
                        .padding(.top, 8)
                }

                // 文字だけのリンクが3つ縦に並んでいて、押せるものだと分かりづらかった。
                // 枠を付けて、押せることと並びの区切りを見えるようにする。
                Button("ことづてを書く") { isWriting = true }
                    .buttonStyle(OutlineButtonStyle(tint: Theme.accent))
                    .padding(.top, 14)

                Button("招待をもらっている") { showsCodeEntry.toggle() }
                    .buttonStyle(OutlineButtonStyle())
                    .padding(.top, 12)

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

                        Button("すすむ") { router.accept(token: enteredCode) }
                            .font(Theme.font(15, weight: .bold))
                            .foregroundStyle(enteredCode.isEmpty ? Theme.inkSoft : Theme.accent)
                            .disabled(enteredCode.isEmpty)
                    }
                    .padding(.top, 12)
                }

                // 相手が受けるのを待たずにアプリを使える。ことづてはペア未成立でも
                // 書けるので、この画面で足止めする理由が無い。
                // サインアウトはここには置かない（設定にある。戻れなくなるほうが困る）。
                Button("ホームに戻る") { onHome() }
                    .buttonStyle(OutlineButtonStyle())
                    .padding(.top, 32)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        // 開いた時点でリンクを用意しておく。誘うのが目的の画面なので、
        // 「つくる」を挟まずそのまま送れるようにする。
        .sheet(isPresented: $isWriting) {
            WriteView { body, color in Task { await store.write(body, color: color) } }
        }
        .task {
            if store.inviteToken == nil { await store.createInvite() }
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

                StickyNote(kotozute: first, paper: Theme.stickyPaper(at: 0), tilt: -2)
                    .frame(width: 208)
            }
            .padding(.top, 28)
        }
    }

    /// リンクとコードの両方を載せる。独自スキームのリンクは
    /// アプリによっては押せないので、コードだけでも受け取れるようにする。
    private static func message(token: String) -> String {
        """
        ことづてに誘われている。
        kotozute://invite/\(token)

        リンクが開けないときは、このコードを入れてほしい:
        \(token)
        """
    }
}
