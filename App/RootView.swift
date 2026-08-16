import KotozuteAPI
import SwiftUI

/// 認証の状態で入口を分ける。サインイン後は GET /me を起点に画面を決める。
struct RootView: View {
    @Bindable var auth: AuthStore

    var body: some View {
        Group {
            switch auth.phase {
            case .checking:
                loading
            case .signedOut:
                AuthView(auth: auth)
            case let .needsConfirmation(email):
                ConfirmView(auth: auth, email: email)
            case .signedIn:
                // サインインし直したら作り直したいので、認証済みかどうかを id にする。
                SignedInView(auth: auth)
                    .id("signed-in")
            }
        }
        .task { await auth.restore() }
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
    @State private var store: KotozuteStore

    init(auth: AuthStore) {
        self.auth = auth
        // TokenProvider に認証層をそのまま渡す。API クライアントは
        // トークンの取得元が Cognito であることを知らない。
        _store = State(initialValue: KotozuteStore(
            client: KotozuteClient(
                baseURL: Config.apiBaseURL,
                tokenProvider: auth.authenticator
            )
        ))
    }

    var body: some View {
        Group {
            switch store.phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background.ignoresSafeArea())
            case .needsProfile:
                ProfileSetupView(store: store)
            case .noPair:
                InviteView(store: store, auth: auth)
            case .ready:
                HomeView(store: store, auth: auth)
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
            Text("名前")
                .font(Theme.font(26, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("相手の画面に出る名前。")
                .font(Theme.font(14))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 8)

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

/// ペア未成立のとき。招待リンクを作って渡す。
struct InviteView: View {
    @Bindable var store: KotozuteStore
    @Bindable var auth: AuthStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("ふたりではじめる")
                .font(Theme.font(26, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("リンクを送って、相手に開いてもらう。")
                .font(Theme.font(14))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 8)

            if let token = store.inviteToken {
                Text(token)
                    .font(Theme.font(13, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                    .padding(.top, 24)

                ShareLink(item: "ことづてに誘われている。招待コード: \(token)") {
                    Text("リンクを送る")
                        .font(Theme.font(17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accent)
                        .clipShape(Capsule())
                }
                .padding(.top, 20)
            } else {
                Button("招待をつくる") {
                    Task { await store.createInvite() }
                }
                .font(Theme.font(17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.accent)
                .clipShape(Capsule())
                .padding(.top, 28)
            }

            Button("サインアウト") {
                Task { await auth.signOut() }
            }
            .font(Theme.font(14))
            .foregroundStyle(Theme.inkSoft)
            .padding(.top, 24)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}
