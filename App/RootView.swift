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
                        onSignIn: { entry = .signIn },
                        // コードを受け取ると pendingToken が入り、上の「誰からの招待か」に切り替わる。
                        onInviteCode: { router.accept(token: $0) }
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
                    // 設定でコードを入れると pendingToken が入り、上の受諾の画面に切り替わる。
                    MainTabView(
                        store: store, auth: auth, wall: wall, calendar: calendar,
                        onInvite: { showsHomeWithoutPair = false },
                        onInviteCode: { router.accept(token: $0) }
                    )
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
/// **2段階にする。** 1段階目でできることは「リンクを送る」だけ（いちばん下に小さく「あとで送る」）。
/// 送ったあと（共有シートで実際に送ったときだけ）に、2段階目として
/// 「ことづてを書いておきますか？」を出す。
///
/// 以前は1つの画面に、送る・書く・招待コードを見る・招待をもらっている・あとで、が並び、
/// どれを押せばいいのか迷った。とくに「ことづてを書く」が送るボタンの上にあったり、
/// 招待された人向けの「招待をもらっている」が送る人の画面の真ん中にあったりした。
/// 招待コードを入れる入口は、最初の「はじめる」の画面と設定に移した（InviteCodeEntryView）。
///
/// 画面の高さいっぱいに広げ、ボタンは下寄りに置く（上に詰めると親指で押しにくい）。
struct InviteView: View {
    @Bindable var store: KotozuteStore
    @Bindable var auth: AuthStore
    @Bindable var router: InviteRouter
    /// 登録直後の流れで来たときだけ、何枚目かの点を出す（設定から来たときは出さない）。
    var showsSteps = false
    /// ペアを待たずにアプリへ入る。
    var onHome: () -> Void = {}
    @State private var isWriting = false
    /// 共有シートで実際に送った（閉じただけではない）。2段階目に進む。
    @State private var didSend = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
        ScrollView {
            VStack(spacing: 0) {
                if showsSteps {
                    OnboardingSteps(current: 2)
                        .padding(.top, 20)
                }

                Text(didSend ? "送りました" : "ふたりではじめる")
                    .font(Theme.font(26, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, showsSteps ? 32 : 48)

                Text(subtitle)
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 10)

                Spacer(minLength: 24)

                firstNote

                Spacer(minLength: 32)

                if didSend {
                    afterSend
                } else {
                    beforeSend
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
            .frame(minHeight: proxy.size.height)
        }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        // 開いた時点でリンクを用意しておく。誘うのが目的の画面なので、
        // 「つくる」を挟まずそのまま送れるようにする。
        // 開くたび・アプリに戻るたびに確かめる。何日も開きっぱなしにしていると、
        // 期限の切れたリンクを送ってしまう。
        .task { await store.ensureFreshInvite() }
        .sheet(isPresented: $isWriting) {
            WriteView { body, color in Task { await store.write(body, color: color) } }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.ensureFreshInvite() } }
        }
    }

    private var subtitle: String {
        if !didSend { return "リンクを送れば、それだけで始められます。" }
        if store.myKotozute.isEmpty { return "ことづてを書いておきますか？\n相手が最初に読むのは、このことづてです。" }
        return "相手が登録して招待コードを入れると、\nペアになります。"
    }

    /// 1段階目。できることは送ることだけ。
    @ViewBuilder
    private var beforeSend: some View {
        if let token = store.inviteToken {
            primaryButton("リンクを送る", systemImage: "square.and.arrow.up") { share(token) }
        } else {
            ProgressView()
                .frame(height: 56)
        }

        // 送る相手がまだ決まっていない人の逃げ道。無いと、ここから先に進めなくなる。
        Button("あとで送る") { onHome() }
            .font(Theme.font(14))
            .foregroundStyle(Theme.inkSoft)
            .padding(.top, 28)
    }

    /// 2段階目。まだ1枚も無ければ、書いておくかを聞く。
    @ViewBuilder
    private var afterSend: some View {
        if store.myKotozute.isEmpty {
            primaryButton("ことづてを書く", systemImage: "square.and.pencil") { isWriting = true }
            Button("あとで") { onHome() }
                .font(Theme.font(15))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 20)
        } else {
            primaryButton("ホームへ", systemImage: nil) { onHome() }
        }

        // 送り損ねた・別の人に送り直したいとき。
        if let token = store.inviteToken {
            Button("もう一度送る") { share(token) }
                .font(Theme.font(14))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 16)
        }
    }

    private func primaryButton(_ title: String, systemImage: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(Theme.font(17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accent)
            .clipShape(Capsule())
        }
    }

    /// 共有シートを出す。
    ///
    /// ShareLink ではなく UIActivityViewController を使うのは、送ったのか
    /// 閉じただけなのかを知るため。送ったときだけ2段階目に進む。
    private func share(_ token: String) {
        let sheet = UIActivityViewController(activityItems: [Self.message(token: token)], applicationActivities: nil)
        sheet.completionWithItemsHandler = { _, completed, _, _ in
            if completed {
                withAnimation(.easeInOut(duration: 0.2)) { didSend = true }
            }
        }
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first
        else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        // iPad では吹き出しの出どころが要る（無いと落ちる）。画面の中央下から出す。
        sheet.popoverPresentationController?.sourceView = top.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY, width: 0, height: 0)
        top.present(sheet, animated: true)
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

                // 正方形に固定する。高さを決めないと、上下の余白（Spacer）のぶんまで紙が伸びる。
                StickyNote(kotozute: first, paper: first.color.flatMap(Theme.stickyPaper(hex:)) ?? Theme.stickyPaper(at: 0), tilt: -2)
                    .frame(width: 208, height: 208)
            }
        } else {
            // まだ1枚も無い人には、ふたりぶんの白紙を飾りとして置く。
            // 押せるものに見えないよう、文字もボタンも載せない。
            HStack(spacing: -28) {
                SampleNote(text: "", paperIndex: 0, tilt: -6, side: 116)
                SampleNote(text: "", paperIndex: 3, tilt: 5, side: 116)
                    .offset(y: 14)
            }
            .accessibilityHidden(true)
        }
    }

    /// 「リンクを送る」で LINE などに貼られる文。リンクとコードの両方を載せる。
    ///
    /// **送る本人の言葉で、ていねいに。** 以前は「ことづてに誘われている。」で始まっていて、
    /// 受け取った側の言い方だった（送り主が「私が誘われている」と言っているように読める）。
    ///
    /// **App Store のリンクを入れる。** 相手はまだアプリを持っていない。
    /// 独自スキームのリンク（kotozute://）は LINE やメッセージでは押せる形にならないので、
    /// コードを入れてもらう。入れる場所は、最初の画面の「招待コードをお持ちの方」。
    private static func message(token: String) -> String {
        """
        「ことづて」というアプリで、ありがとうを送り合いませんか？
        こちらからダウンロードできます。
        \(Config.appStoreURL.absoluteString)

        アプリを開いたら、最初の画面の「招待コードをお持ちの方」から、このコードを入れてください。
        \(token)
        """
    }
}
