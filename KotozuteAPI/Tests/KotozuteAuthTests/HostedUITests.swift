import Foundation
import Testing
@testable import KotozuteAuth

struct HostedUITests {
    let config = HostedUIConfiguration(
        domain: "kotozute.auth.ap-northeast-1.amazoncognito.com",
        clientId: "client123",
        redirectURI: "kotozute://auth/callback"
    )

    @Test func pkceChallengeMatchesRFC7636Example() {
        // RFC 7636 Appendix B の例。
        let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func generatedVerifierIsURLSafeAndLongEnough() {
        let pkce = PKCE.generate()
        #expect(pkce.verifier.count >= 43)
        #expect(pkce.verifier.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        #expect(PKCE.generate() != pkce)
    }

    @Test func authorizeURLGoesStraightToProvider() throws {
        let pkce = PKCE(verifier: "v")
        let url = HostedUI.authorizeURL(configuration: config, provider: .apple, pkce: pkce, state: "s1")
        let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let q = Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(comps.host == "kotozute.auth.ap-northeast-1.amazoncognito.com")
        #expect(comps.path == "/oauth2/authorize")
        #expect(q["identity_provider"] == "SignInWithApple")
        #expect(q["response_type"] == "code")
        #expect(q["client_id"] == "client123")
        #expect(q["redirect_uri"] == "kotozute://auth/callback")
        #expect(q["state"] == "s1")
        #expect(q["code_challenge"] == pkce.challenge)
        #expect(q["code_challenge_method"] == "S256")
        #expect(config.callbackScheme == "kotozute")
    }

    @Test func parseCallbackReturnsCode() throws {
        let url = URL(string: "kotozute://auth/callback?code=abc&state=s1")!
        #expect(try HostedUI.parseCallback(url, expectedState: "s1") == "abc")
    }

    @Test func parseCallbackRejectsWrongState() {
        let url = URL(string: "kotozute://auth/callback?code=abc&state=other")!
        #expect(throws: HostedUIError.stateMismatch) {
            try HostedUI.parseCallback(url, expectedState: "s1")
        }
    }

    @Test func parseCallbackDetectsAccountLinked() {
        let url = URL(string: "kotozute://auth/callback?error_description=PreSignUp+failed+Already+found+an+entry+for+username+Google_123&error=invalid_request")!
        #expect(throws: HostedUIError.accountLinked) {
            try HostedUI.parseCallback(url, expectedState: "s1")
        }
    }

    @Test func parseCallbackPassesOtherErrors() {
        let url = URL(string: "kotozute://auth/callback?error=access_denied&state=s1")!
        #expect(throws: HostedUIError.provider(description: "access_denied")) {
            try HostedUI.parseCallback(url, expectedState: "s1")
        }
    }

    @Test func tokenRequestBodyIsFormEncoded() {
        let body = String(decoding: HostedUI.tokenRequestBody(configuration: config, code: "c+d", verifier: "v1"), as: UTF8.self)
        #expect(body.contains("grant_type=authorization_code"))
        #expect(body.contains("client_id=client123"))
        #expect(body.contains("code=c%2Bd"))
        #expect(body.contains("code_verifier=v1"))
        #expect(body.contains("redirect_uri=kotozute://auth/callback") || body.contains("redirect_uri=kotozute%3A%2F%2Fauth%2Fcallback"))
    }
}
