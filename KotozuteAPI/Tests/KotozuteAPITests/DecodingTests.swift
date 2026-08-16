import XCTest
@testable import KotozuteAPI

/// サーバーが実際に返す JSON の形に対して、デコードが壊れないことを確かめる。
/// 特に日時まわりはバックエンドの実装（Go）で2種類の形式が混在しているので厚めに見る。
final class DecodingTests: XCTestCase {

    // MARK: - GET /kotozute/this-week

    /// canSeePartner=false のとき、サーバーは partnerKotozute のキー自体を返さない。
    /// キー欠落で全体のデコードが落ちず、空配列になること。
    func testThisWeekOmitsPartnerKotozuteWhenLocked() async throws {
        let json = """
        {
          "myKotozute": [],
          "openStatus": "opened",
          "canSeePartner": false,
          "partnerHasWritten": true,
          "nextOpenAt": "2026-08-14T20:00"
        }
        """
        let transport = StubTransport(json: json)
        let response = try await KotozuteClient.stubbed(transport: transport).thisWeek()

        XCTAssertFalse(response.canSeePartner)
        XCTAssertTrue(response.lastCycle.partner.isEmpty)
        XCTAssertTrue(response.partnerHasWritten)
    }

    /// ペア未成立のとき nextOpenAt は省略ではなく空文字で返る（get-this-week/main.go）。
    /// 空文字を nil に畳めること。
    func testEmptyNextOpenAtBecomesNil() async throws {
        let json = """
        {
          "myKotozute": [],
          "openStatus": "before",
          "canSeePartner": false,
          "partnerHasWritten": false,
          "nextOpenAt": ""
        }
        """
        let transport = StubTransport(json: json)
        let response = try await KotozuteClient.stubbed(transport: transport).thisWeek()

        XCTAssertNil(response.nextOpenAt)
    }

    /// createdAt は RFC3339。Date に変換できること。
    func testKotozuteCreatedAtIsParsedAsDate() async throws {
        let json = """
        {
          "myKotozute": [
            { "id": "k1", "body": "今日はありがとう", "createdAt": "2026-08-11T12:34:56Z" }
          ],
          "openStatus": "before",
          "canSeePartner": false,
          "partnerHasWritten": false,
          "nextOpenAt": ""
        }
        """
        let transport = StubTransport(json: json)
        let response = try await KotozuteClient.stubbed(transport: transport).thisWeek()

        let item = try XCTUnwrap(response.myKotozute.first)
        XCTAssertEqual(item.id, "k1")
        XCTAssertEqual(item.body, "今日はありがとう")
        XCTAssertEqual(item.createdAt, Date(timeIntervalSince1970: 1_786_451_696))
    }

    // MARK: - WallClock

    /// nextOpenAt は秒もタイムゾーンも持たないので、標準の ISO8601 デコーダでは扱えない。
    /// タイムゾーンを与えて初めて絶対時刻になる。
    func testWallClockNeedsTimeZoneToBecomeDate() throws {
        let wallClock = WallClock("2026-08-14T20:00")
        let tokyo = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))

        let inTokyo = try XCTUnwrap(wallClock.date(in: tokyo))
        let inUTC = try XCTUnwrap(wallClock.date(in: utc))

        // 同じ文字列でも解釈するタイムゾーンが違えば9時間ずれる。
        XCTAssertEqual(inUTC.timeIntervalSince(inTokyo), 9 * 3600)
    }

    /// 形式が壊れていても値は保持し、変換だけが nil になること（レスポンス全体を落とさない）。
    func testWallClockKeepsRawValueWhenUnparsable() throws {
        let wallClock = WallClock("こわれた値")
        let tokyo = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))

        XCTAssertEqual(wallClock.rawValue, "こわれた値")
        XCTAssertNil(wallClock.date(in: tokyo))
    }

    // MARK: - GET /me

    func testMeResponseWithoutPair() async throws {
        let json = """
        { "userId": "u1", "displayName": "けんと", "pairStatus": "none" }
        """
        let transport = StubTransport(json: json)
        let response = try await KotozuteClient.stubbed(transport: transport).me()

        XCTAssertEqual(response.pairStatus, .none)
        XCTAssertNil(response.pairId)
        XCTAssertNil(response.nextOpenAt)
        XCTAssertNil(response.email)
    }

    // MARK: - GET /pair

    func testPairResponse() async throws {
        let json = """
        {
          "pairId": "p1",
          "partner": { "userId": "u2", "displayName": "あい" },
          "openDayOfWeek": 5,
          "openTime": "20:00",
          "timezone": "Asia/Tokyo",
          "status": "active",
          "nextOpenAt": "2026-08-14T20:00"
        }
        """
        let transport = StubTransport(json: json)
        let response = try await KotozuteClient.stubbed(transport: transport).pair()

        XCTAssertEqual(response.partner.displayName, "あい")
        XCTAssertEqual(response.openDayOfWeek, 5)
        XCTAssertEqual(response.nextOpenAt?.rawValue, "2026-08-14T20:00")
    }

    // MARK: - アーカイブ

    func testArchiveNextCursorIsNilAtEnd() async throws {
        let json = """
        { "items": [], "nextCursor": null }
        """
        let transport = StubTransport(json: json)
        let response = try await KotozuteClient.stubbed(transport: transport)
            .archive(whose: .partner, year: 2026, month: 6)

        XCTAssertTrue(response.items.isEmpty)
        XCTAssertNil(response.nextCursor)
    }
}
