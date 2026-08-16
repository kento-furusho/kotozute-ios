import XCTest
@testable import KotozuteAuth
import KotozuteAPI

/// 実際の Cognito と API に繋ぐテスト。通信するので既定では走らせない。
///
///   KOTOZUTE_E2E=1 swift test --filter CognitoIntegrationTests
///
/// 事前に確認済みのテストユーザーが必要（admin-create-user + admin-set-user-password で作る）。
final class CognitoIntegrationTests: XCTestCase {

    private let clientId = "1hbuhnvdap6ah8e9tcs5elnuq"
    private let region = "ap-northeast-1"
    private let baseURL = URL(string: "https://fce7tbbiq5.execute-api.ap-northeast-1.amazonaws.com/Prod")!
    private let email = "test@example.com"
    private let password = "kotozute123"

    private var isEnabled: Bool {
        ProcessInfo.processInfo.environment["KOTOZUTE_E2E"] == "1"
    }

    private func makeAuthenticator() throws -> CognitoAuthenticator {
        try CognitoAuthenticator(
            configuration: CognitoConfiguration(clientId: clientId, region: region),
            // Keychain は macOS 上のテストで確認ダイアログを出しうるので、メモリに置く。
            tokenStore: InMemoryTokenStore()
        )
    }

    /// サインインして IdToken が取れること。
    func testSignInReturnsIdToken() async throws {
        try XCTSkipUnless(isEnabled, "KOTOZUTE_E2E=1 のときだけ実行する")

        let authenticator = try makeAuthenticator()
        try await authenticator.signIn(email: email, password: password)

        let token = try await authenticator.idToken()
        // JWT は3つのセグメントからなる。
        XCTAssertEqual(token.split(separator: ".").count, 3)

        // 期限が未来であること（切れたトークンを掴んでいない）。
        let expiry = CognitoAuthenticator.expiry(of: token)
        XCTAssertGreaterThan(expiry, Date())
    }

    /// 取れたトークンで実際の API が通ること。
    /// ここまで通れば、認証・API Gateway・Lambda が一本に繋がっている。
    func testAuthenticatedRequestReachesAPI() async throws {
        try XCTSkipUnless(isEnabled, "KOTOZUTE_E2E=1 のときだけ実行する")

        let authenticator = try makeAuthenticator()
        try await authenticator.signIn(email: email, password: password)

        let client = KotozuteClient(baseURL: baseURL, tokenProvider: authenticator)

        do {
            let me = try await client.me()
            XCTAssertFalse(me.userId.isEmpty)
        } catch let error as APIError {
            // プロフィール未登録なら 404。認証は通っている（401 ではない）ので想定内。
            guard case .notFound = error else {
                return XCTFail("想定外のエラー: \(error)")
            }
        }
    }

    /// 間違ったパスワードが 401 相当として扱われること。
    func testWrongPasswordIsRejected() async throws {
        try XCTSkipUnless(isEnabled, "KOTOZUTE_E2E=1 のときだけ実行する")

        let authenticator = try makeAuthenticator()
        do {
            try await authenticator.signIn(email: email, password: "wrong-password-12345")
            XCTFail("サインインが通ってしまった")
        } catch let error as AuthError {
            XCTAssertEqual(error, .invalidCredentials)
        }
    }
}

/// 通信しないほうのテスト。
final class TokenExpiryTests: XCTestCase {

    /// JWT の exp を読めること。署名は検証しない（サーバーの仕事）。
    func testExpiryIsReadFromJWTPayload() {
        // {"exp":1786451696} を Base64URL にしたもの。
        let payload = "eyJleHAiOjE3ODY0NTE2OTZ9"
        let jwt = "header.\(payload).signature"

        XCTAssertEqual(
            CognitoAuthenticator.expiry(of: jwt),
            Date(timeIntervalSince1970: 1_786_451_696)
        )
    }

    /// 壊れたトークンは即時失効扱いにして、次の呼び出しでリフレッシュさせる。
    func testUnparsableTokenExpiresImmediately() {
        XCTAssertEqual(CognitoAuthenticator.expiry(of: "not-a-jwt"), .distantPast)
    }

    /// Base64URL のパディング省略を補えること。
    func testBase64URLDecodingHandlesMissingPadding() {
        XCTAssertEqual(
            CognitoAuthenticator.base64URLDecode("eyJhIjoxfQ").map { String(decoding: $0, as: UTF8.self) },
            #"{"a":1}"#
        )
    }
}
