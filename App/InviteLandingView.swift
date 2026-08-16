import KotozuteAPI
import SwiftUI

/// 招待リンクを開いた側の入口。まだサインインしていない段階でも「誰からの招待か」を出す。
struct InviteLandingView: View {
    @Bindable var router: InviteRouter
    /// 続きへ進む（サインイン／登録へ）。
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if router.isLoading {
                ProgressView()
            } else if let message = router.errorMessage {
                Text(message)
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)

                Button("とじる") { router.clear() }
                    .font(Theme.font(16, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 20)
            } else if let preview = router.preview {
                Text("\(preview.inviterDisplayName)からの招待")
                    .font(Theme.font(26, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)

                Text("ふたりで、いいなと思ったことを書きためる。\n週に一度まとめて読む。")
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 12)

                Button(action: onContinue) {
                    Text("はじめる")
                        .font(Theme.font(17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accent)
                        .clipShape(Capsule())
                }
                .padding(.top, 32)

                Button("やめる") { router.clear() }
                    .font(Theme.font(14))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 16)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}

/// サインイン済みで、受ける招待を抱えている状態。ここで受諾してペアを成立させる。
struct AcceptInviteView: View {
    @Bindable var router: InviteRouter
    @Bindable var store: KotozuteStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if let preview = router.preview {
                Text("\(preview.inviterDisplayName)とはじめる")
                    .font(Theme.font(26, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
            } else {
                Text("招待を受ける")
                    .font(Theme.font(26, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }

            if let message = router.errorMessage ?? store.acceptError {
                Text(message)
                    .font(Theme.font(14))
                    .foregroundStyle(Theme.accent)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
            }

            if let token = router.pendingToken, router.errorMessage == nil {
                Button {
                    Task {
                        await store.acceptInvite(token: token)
                        if store.acceptError == nil { router.clear() }
                    }
                } label: {
                    Group {
                        if store.isAccepting {
                            ProgressView().tint(.white)
                        } else {
                            Text("ふたりではじめる").font(Theme.font(17, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.accent)
                    .clipShape(Capsule())
                }
                .disabled(store.isAccepting)
                .padding(.top, 32)
            }

            Button("やめる") { router.clear() }
                .font(Theme.font(14))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 16)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .task {
            #if DEBUG
            // シミュレータでの確認用。タップの代わりに受諾まで進める。
            //   xcrun simctl launch <udid> dev.kotozute.app --signin <mail> <pass> --invite <token> --auto-accept
            guard ProcessInfo.processInfo.arguments.contains("--auto-accept"),
                  let token = router.pendingToken else { return }
            await store.acceptInvite(token: token)
            if store.acceptError == nil { router.clear() }
            #endif
        }
    }
}
