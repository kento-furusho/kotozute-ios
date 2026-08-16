import Foundation
import KotozuteAPI
import KotozuteAuth
import Observation

/// 認証の状態と操作をまとめて画面に渡す。
@Observable
@MainActor
final class AuthStore {
    enum Phase: Equatable {
        /// 起動直後。保存済みトークンの有無を確かめている。
        case checking
        case signedOut
        /// サインアップ済みだが確認コード待ち。
        case needsConfirmation(email: String)
        case signedIn
    }

    private(set) var phase: Phase = .checking
    private(set) var errorMessage: String?
    private(set) var isWorking = false

    let authenticator: CognitoAuthenticator

    init() throws {
        authenticator = try CognitoAuthenticator(
            configuration: CognitoConfiguration(
                clientId: Config.userPoolClientId,
                region: Config.region
            ),
            tokenStore: KeychainTokenStore()
        )
    }

    /// 起動時に呼ぶ。保存されたトークンで続きから始められるかを見る。
    func restore() async {
        #if DEBUG
        // シミュレータで画面を確認するための入口。製品ビルドには入らない。
        //   xcrun simctl launch <udid> dev.kotozute.app --signin <メール> <パスワード>
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--signin"), index + 2 < arguments.count {
            await signIn(email: arguments[index + 1], password: arguments[index + 2])
            // 失敗しても .checking のままだと画面がローディングから戻らない。
            // サインイン画面に落として、errorMessage を見せる。
            if phase == .checking { phase = .signedOut }
            return
        }
        #endif

        // idToken() は期限切れならリフレッシュまで面倒を見る。
        // ここを通れば、再起動してもサインインし直さずに済む。
        do {
            _ = try await authenticator.idToken()
            phase = .signedIn
        } catch {
            phase = .signedOut
        }
    }

    func signUp(email: String, password: String) async {
        await perform {
            try await self.authenticator.signUp(email: email, password: password)
            self.phase = .needsConfirmation(email: email)
        }
    }

    func confirm(email: String, code: String, password: String) async {
        await perform {
            try await self.authenticator.confirmSignUp(email: email, code: code)
            // 確認が通ったらそのままサインインまで済ませる。コード入力の直後に
            // もう一度パスワードを打たせない。
            try await self.authenticator.signIn(email: email, password: password)
            self.phase = .signedIn
        }
    }

    func resendCode(email: String) async {
        await perform {
            try await self.authenticator.resendCode(email: email)
        }
    }

    func signIn(email: String, password: String) async {
        await perform {
            do {
                try await self.authenticator.signIn(email: email, password: password)
                self.phase = .signedIn
            } catch AuthError.notConfirmed {
                // 登録はできているがコード未確認。確認画面へ送る。
                self.phase = .needsConfirmation(email: email)
            }
        }
    }

    func signOut() async {
        try? await authenticator.signOut()
        phase = .signedOut
    }

    func clearError() {
        errorMessage = nil
    }

    private func perform(_ work: @escaping () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await work()
        } catch let error as AuthError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func message(for error: AuthError) -> String {
        switch error {
        case .invalidCredentials: "メールアドレスかパスワードが違う。"
        case .notConfirmed: "まだ確認が済んでいない。"
        case .emailAlreadyExists: "このメールアドレスは登録済み。"
        case .invalidCode: "確認コードが違う。"
        case .codeExpired: "確認コードの期限が切れた。送り直してほしい。"
        case .weakPassword: "パスワードは8文字以上で、小文字と数字を含める。"
        case .notSignedIn, .sessionExpired: "もう一度サインインしてほしい。"
        case .keychain: "端末への保存に失敗した。"
        case let .underlying(message): message
        }
    }
}
