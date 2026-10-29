import XCTest
@testable import KotozuteAPI

/// 招待リンクの解析。外から来る URL をそのまま信じないための境界。
final class InviteLinkTests: XCTestCase {

    func testRoundTrip() throws {
        let token = "97dd3d3b-800d-4039-aac4-decf26afc0de"
        let url = try XCTUnwrap(InviteLink.url(token: token))

        XCTAssertEqual(url.absoluteString, "kotozute://invite/\(token)")
        XCTAssertEqual(InviteLink.token(from: url), token)
    }

    /// 別のスキーム・別のホストでは受け取らない。
    /// 他のアプリからの URL や、将来別の導線を足したときの誤動作を防ぐ。
    func testRejectsForeignURLs() throws {
        let rejected = [
            "https://invite/abc",              // スキーム違い
            "kotozute://pair/abc",             // ホスト違い
            "kotozute://invite",               // トークン無し
            "kotozute://invite/",              // トークン空
            "kotozute://invite/abc/extra",     // 余計な階層
        ]
        for string in rejected {
            let url = try XCTUnwrap(URL(string: string), string)
            XCTAssertNil(InviteLink.token(from: url), "受け取ってはいけない: \(string)")
        }
    }

    func testEmptyTokenMakesNoURL() {
        XCTAssertNil(InviteLink.url(token: ""))
    }
}
