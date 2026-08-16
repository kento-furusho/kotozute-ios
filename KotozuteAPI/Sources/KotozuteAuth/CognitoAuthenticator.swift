import AWSCognitoIdentityProvider
import Foundation
import KotozuteAPI

public struct CognitoConfiguration: Sendable {
    public let clientId: String
    public let region: String

    public init(clientId: String, region: String) {
        self.clientId = clientId
        self.region = region
    }
}

/// Cognito のユーザープールに対するサインアップ／サインイン。
///
/// Amplify を使わず、素の AWS SDK for Swift で `InitiateAuth` などを直接叩く。
/// 認証フローは `USER_PASSWORD_AUTH`。SDK に SRP のヘルパーが無く、SRP を使うには
/// プロトコル自体を自前で実装する必要があるため、まずはこちらで繋ぐ。
/// 差し替えるときはこの型の中だけで閉じる。
///
/// actor にしているのは、トークンの更新が同時に走って二重にリフレッシュするのを防ぐため。
public actor CognitoAuthenticator: TokenProvider {
    private let configuration: CognitoConfiguration
    private let tokenStore: any TokenStore
    private let client: CognitoIdentityProviderClient

    /// IdToken の期限が近いときは前倒しで更新する。通信のあいだに切れるのを避けるため。
    private let refreshMargin: TimeInterval = 120

    public init(configuration: CognitoConfiguration, tokenStore: any TokenStore) throws {
        self.configuration = configuration
        self.tokenStore = tokenStore
        self.client = try CognitoIdentityProviderClient(region: configuration.region)
    }

    // MARK: - 状態

    public var isSignedIn: Bool {
        (try? tokenStore.load()) .flatMap { $0 } != nil
    }

    // MARK: - サインアップ

    /// メールアドレスとパスワードで登録する。確認コードがメールに送られる。
    public func signUp(email: String, password: String) async throws {
        do {
            _ = try await client.signUp(input: SignUpInput(
                clientId: configuration.clientId,
                password: password,
                username: email
            ))
        } catch {
            throw Self.translate(error)
        }
    }

    /// メールに届いた確認コードを検証する。これを通すとサインインできるようになる。
    public func confirmSignUp(email: String, code: String) async throws {
        do {
            _ = try await client.confirmSignUp(input: ConfirmSignUpInput(
                clientId: configuration.clientId,
                confirmationCode: code,
                username: email
            ))
        } catch {
            throw Self.translate(error)
        }
    }

    /// 確認コードを送り直す。
    public func resendCode(email: String) async throws {
        do {
            _ = try await client.resendConfirmationCode(input: ResendConfirmationCodeInput(
                clientId: configuration.clientId,
                username: email
            ))
        } catch {
            throw Self.translate(error)
        }
    }

    // MARK: - サインイン

    public func signIn(email: String, password: String) async throws {
        let output: InitiateAuthOutput
        do {
            output = try await client.initiateAuth(input: InitiateAuthInput(
                authFlow: .userPasswordAuth,
                authParameters: ["USERNAME": email, "PASSWORD": password],
                clientId: configuration.clientId
            ))
        } catch {
            throw Self.translate(error)
        }

        guard let result = output.authenticationResult,
              let idToken = result.idToken,
              let refreshToken = result.refreshToken
        else {
            // MFA などの追加チャレンジは今の設定では起きない。起きたら想定外として扱う。
            throw AuthError.underlying(message: "認証結果が取得できませんでした")
        }

        try tokenStore.save(AuthTokens(
            idToken: idToken,
            refreshToken: refreshToken,
            expiresAt: Self.expiry(of: idToken)
        ))
    }

    public func signOut() throws {
        try tokenStore.clear()
    }

    // MARK: - TokenProvider

    /// 有効な IdToken を返す。期限が近ければリフレッシュしてから返す。
    /// API クライアントはこのメソッドしか知らないので、更新の都合が上位に漏れない。
    public func idToken() async throws -> String {
        guard let tokens = try tokenStore.load() else {
            throw AuthError.notSignedIn
        }
        if tokens.expiresAt.timeIntervalSinceNow > refreshMargin {
            return tokens.idToken
        }
        return try await refresh(using: tokens.refreshToken)
    }

    private func refresh(using refreshToken: String) async throws -> String {
        let output: InitiateAuthOutput
        do {
            output = try await client.initiateAuth(input: InitiateAuthInput(
                authFlow: .refreshTokenAuth,
                authParameters: ["REFRESH_TOKEN": refreshToken],
                clientId: configuration.clientId
            ))
        } catch {
            // リフレッシュトークンも失効している。再サインインしてもらうしかない。
            try? tokenStore.clear()
            throw AuthError.sessionExpired
        }

        guard let idToken = output.authenticationResult?.idToken else {
            try? tokenStore.clear()
            throw AuthError.sessionExpired
        }

        // リフレッシュ時に新しい refreshToken は返らないので、元のものを持ち回る。
        try tokenStore.save(AuthTokens(
            idToken: idToken,
            refreshToken: refreshToken,
            expiresAt: Self.expiry(of: idToken)
        ))
        return idToken
    }

    // MARK: - 内部

    private static func translate(_ error: any Error) -> AuthError {
        if let error = error as? AuthError { return error }
        // SDK が投げるモデル化されたエラーは、型名が Cognito の例外名そのもの
        // （NotAuthorizedException など）。SDK 内部の型に依存せず、型名で判定する。
        return AuthError.from(
            exceptionName: String(describing: type(of: error)),
            message: error.localizedDescription
        )
    }

    /// JWT の exp から失効時刻を取り出す。
    /// 署名の検証はしない（それはサーバー側の仕事）。ここでは更新のタイミングを知りたいだけ。
    static func expiry(of jwt: String) -> Date {
        let segments = jwt.split(separator: ".")
        guard segments.count >= 2,
              let payload = base64URLDecode(String(segments[1])),
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let exp = json["exp"] as? Double
        else {
            // 読めなければ即時失効扱いにして、次の呼び出しでリフレッシュさせる。
            return .distantPast
        }
        return Date(timeIntervalSince1970: exp)
    }

    static func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Base64URL はパディングを省くので補う。
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}
