import AuthenticationServices
import UIKit

/// アカウントを消す直前の、Apple の本人確認。
///
/// Apple でログインした人がアカウントを消すときは、Apple 側の連携も取り消す
/// （App Store 審査ガイドライン 5.1.1(v)）。取り消しに要るトークンは Cognito の中にしか無いので、
/// ここで Apple の本人確認をもう一度出して使い捨ての authorizationCode を受け取り、
/// サーバー（DELETE /me）に渡す。サーバーが Apple と引き換えて取り消す。
///
/// ログイン自体は Cognito の Web シート経由のまま。これは削除のときにだけ使う。
@MainActor
final class AppleReauth: NSObject {
    enum Outcome {
        case code(String)
        /// 本人が閉じた。削除そのものをやめる。
        case cancelled
        /// Apple ID に入れない等。取り消しなしで消すかどうかを呼び出し側が決める。
        case failed
    }

    private var continuation: CheckedContinuation<Outcome, Never>?
    private var controller: ASAuthorizationController?

    func run() async -> Outcome {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        // 名前もメールも要らない。欲しいのは code だけ。
        request.requestedScopes = []
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.controller = controller
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    private func finish(_ outcome: Outcome) {
        continuation?.resume(returning: outcome)
        continuation = nil
        controller = nil
    }
}

extension AppleReauth: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        let code = credential?.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        Task { @MainActor in
            self.finish(code.map(Outcome.code) ?? .failed)
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        Task { @MainActor in
            self.finish(cancelled ? .cancelled : .failed)
        }
    }
}

extension AppleReauth: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}
