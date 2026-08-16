import XCTest
@testable import KotozuteAPI

/// 相互ロックの画面分岐。仕様表（docs/ios-kickoff.md）の4行をそのままテストにする。
/// ここを間違えると「書いていない相手に気配を見せる」など、仕様違反が画面に出る。
final class HomeStateTests: XCTestCase {

    private func makeResponse(
        myCount: Int,
        openStatus: OpenStatus,
        canSeePartner: Bool,
        partnerCount: Int,
        partnerHasWritten: Bool
    ) throws -> ThisWeekResponse {
        func items(_ count: Int, prefix: String) -> String {
            (0..<count)
                .map { #"{"id":"\#(prefix)\#($0)","body":"本文","createdAt":"2026-08-11T12:00:00Z"}"# }
                .joined(separator: ",")
        }

        // canSeePartner=false のときサーバーは lastCycle.partner をキーごと返さないので、
        // テストでも同じ形にする。
        let partnerKey = canSeePartner
            ? #", "partner": [\#(items(partnerCount, prefix: "p"))]"#
            : ""
        let json = """
        {
          "myKotozute": [\(items(myCount, prefix: "m"))],
          "openStatus": "\(openStatus.rawValue)",
          "canSeePartner": \(canSeePartner),
          "lastCycle": { "mine": [] \(partnerKey) },
          "partnerHasWritten": \(partnerHasWritten),
          "nextOpenAt": "2026-08-14T20:00"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ThisWeekResponse.self, from: Data(json.utf8))
    }

    /// 自分1枚以上 × 相手オープン済み → 相手のことづてを見せる。
    func testPartnerVisible() throws {
        let response = try makeResponse(
            myCount: 1, openStatus: .opened, canSeePartner: true,
            partnerCount: 2, partnerHasWritten: true
        )
        let state = HomeState(from: response)

        guard case let .partnerVisible(items) = state.screen else {
            return XCTFail("partnerVisible を期待したが \(state.screen)")
        }
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(state.showsPartnerPresence)
    }

    /// 自分1枚以上 × まだオープン前 → 待ちの画面。
    func testWaitingForOpen() throws {
        let response = try makeResponse(
            myCount: 1, openStatus: .before, canSeePartner: false,
            partnerCount: 0, partnerHasWritten: true
        )
        let state = HomeState(from: response)

        XCTAssertEqual(state.screen, .waitingForOpen)
    }

    /// 自分0枚 × 相手オープン済み → ロック（書くと見られる）。
    func testLockedUntilIWrite() throws {
        let response = try makeResponse(
            myCount: 0, openStatus: .opened, canSeePartner: false,
            partnerCount: 0, partnerHasWritten: true
        )
        let state = HomeState(from: response)

        XCTAssertEqual(state.screen, .lockedUntilIWrite)
        XCTAssertTrue(state.showsPartnerPresence)
    }

    /// 自分0枚 × まだオープン前 → 通常ホーム。
    func testPlainHome() throws {
        let response = try makeResponse(
            myCount: 0, openStatus: .before, canSeePartner: false,
            partnerCount: 0, partnerHasWritten: false
        )
        let state = HomeState(from: response)

        XCTAssertEqual(state.screen, .plainHome)
    }

    /// 相手が0枚の週は気配を一切出さない。「まだ書いてない」と読める表示を出さないための担保。
    func testNoPartnerPresenceWhenPartnerHasNotWritten() throws {
        for openStatus in [OpenStatus.before, .opened] {
            for myCount in [0, 1] {
                let response = try makeResponse(
                    myCount: myCount, openStatus: openStatus, canSeePartner: false,
                    partnerCount: 0, partnerHasWritten: false
                )
                XCTAssertFalse(
                    HomeState(from: response).showsPartnerPresence,
                    "相手0枚なのに気配が出ている (openStatus=\(openStatus), myCount=\(myCount))"
                )
            }
        }
    }

    /// 本文を見せるかはサーバーの canSeePartner に従う。
    /// 自分の枚数から推論して上書きしない。
    func testServerDecisionWinsOverLocalInference() throws {
        let response = try makeResponse(
            myCount: 1, openStatus: .opened, canSeePartner: false,
            partnerCount: 0, partnerHasWritten: true
        )
        let state = HomeState(from: response)

        XCTAssertEqual(state.screen, .lockedUntilIWrite)
        if case .partnerVisible = state.screen {
            XCTFail("サーバーが見せないと判断したのに本文を表示しようとしている")
        }
    }

    /// 前のサイクルに書いた人は、今のサイクルが0枚でも相手のことづてを見られる。
    /// このとき myKotozute は空なので、枚数から推論するとロック画面に送ってしまう。
    func testPartnerVisibleEvenWhenMyCurrentCycleIsEmpty() throws {
        let response = try makeResponse(
            myCount: 0, openStatus: .opened, canSeePartner: true,
            partnerCount: 2, partnerHasWritten: false
        )
        let state = HomeState(from: response)

        guard case let .partnerVisible(items) = state.screen else {
            return XCTFail("partnerVisible を期待したが \(state.screen)")
        }
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(response.myKotozute.isEmpty)
    }
}
