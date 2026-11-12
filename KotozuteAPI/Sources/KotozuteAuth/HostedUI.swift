import CryptoKit
import Foundation

/// Apple / Google でのログイン。Cognito の連携（フェデレーション）を Web シート経由で使う。
///
/// 流れ:
///   1. `authorizeURL` を Web シート（ASWebAuthenticationSession）で開く。
///      `identity_provider` を付けるので、Cognito の画面を飛ばして Apple / Google へ直行する
///   2. ログインが済むと `kotozute://auth/callback?code=…&state=…` に戻る → `parseCallback`
///   3. 認可コードを `/oauth2/token` で交換する（`CognitoAuthenticator.signIn(authorizationCode:…)`）
///
/// 返るトークンはメール登録と同じ形（ID トークン＋リフレッシュトークン）なので、
/// その後の API 呼び出しやリフレッシュは今までの仕組みのまま。
///
/// 公開クライアント（シークレットを持てない）なので PKCE で認可コードの横取りを防ぐ。
/// `state` は、別のログインの戻りを取り違えないために照合する。
public struct HostedUIConfiguration: Sendable {
    /// 例: kotozute.auth.ap-northeast-1.amazoncognito.com
    public let domain: String
    public let clientId: String
    /// アプリに戻ってくる先。Cognito のアプリクライアントの CallbackURLs と一致させる。
    public let redirectURI: String

    public init(domain: String, clientId: String, redirectURI: String) {
        self.domain = domain
        self.clientId = clientId
        self.redirectURI = redirectURI
    }

    /// Web シートが戻りを待つ URL スキーム（"kotozute"）。
    public var callbackScheme: String {
        URL(string: redirectURI)?.scheme ?? ""
    }

    var tokenURL: URL { URL(string: "https://\(domain)/oauth2/token")! }
}

/// どこでログインするか。値は Cognito の IdP 名（template.yaml の ProviderName）。
public enum ExternalProvider: String, Sendable, CaseIterable {
    case apple = "SignInWithApple"
    case google = "Google"
}

/// PKCE（Proof Key for Code Exchange）の組。verifier は手元に残し、challenge だけを送る。
public struct PKCE: Sendable, Equatable {
    public let verifier: String
    public let challenge: String

    public init(verifier: String) {
        self.verifier = verifier
        self.challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    /// 32バイトの乱数から作る（43文字。規格の下限）。
    public static func generate() -> PKCE {
        PKCE(verifier: randomToken())
    }

    static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Web シートから戻ったときの失敗。
public enum HostedUIError: Error, Sendable, Equatable {
    /// 同じメールのアカウントに紐づけた直後。Cognito の仕様でこの1回だけ失敗として返る。
    /// もう一度ログインすれば、紐づけた先のアカウントに入れる。
    case accountLinked
    /// 戻りの state が違う。別のログインの戻りか、改ざん。
    case stateMismatch
    /// 戻りに code もエラーも無い。
    case missingCode
    /// Cognito / Apple / Google が返したエラー。
    case provider(description: String)
}

public enum HostedUI {
    /// ログインの入口の URL。
    public static func authorizeURL(
        configuration: HostedUIConfiguration,
        provider: ExternalProvider,
        pkce: PKCE,
        state: String
    ) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = configuration.domain
        components.path = "/oauth2/authorize"
        components.queryItems = [
            URLQueryItem(name: "identity_provider", value: provider.rawValue),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "scope", value: "openid email"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        return components.url!
    }

    /// 戻ってきた URL から認可コードを取り出す。
    public static func parseCallback(_ url: URL, expectedState: String) throws -> String {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        if let error = value("error") {
            // Cognito は空白を "+" で返す（フォーム形式）。URLComponents は "+" を空白に戻さないので直す。
            let description = (value("error_description") ?? error).replacingOccurrences(of: "+", with: " ")
            // 登録前トリガーで既存アカウントに紐づけた直後だけ、この文言で返る。
            if description.contains("Already found an entry for username") {
                throw HostedUIError.accountLinked
            }
            throw HostedUIError.provider(description: description)
        }
        guard value("state") == expectedState else { throw HostedUIError.stateMismatch }
        guard let code = value("code"), !code.isEmpty else { throw HostedUIError.missingCode }
        return code
    }

    /// `/oauth2/token` に送る本文（application/x-www-form-urlencoded）。
    static func tokenRequestBody(
        configuration: HostedUIConfiguration,
        code: String,
        verifier: String
    ) -> Data {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "code_verifier", value: verifier),
        ]
        // URLComponents は "+" をエスケープしないが、フォームでは空白の意味になるので直す。
        let encoded = (components.percentEncodedQuery ?? "")
            .replacingOccurrences(of: "+", with: "%2B")
        return Data(encoded.utf8)
    }

    struct TokenResponse: Decodable {
        let idToken: String
        let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case idToken = "id_token"
            case refreshToken = "refresh_token"
        }
    }
}
