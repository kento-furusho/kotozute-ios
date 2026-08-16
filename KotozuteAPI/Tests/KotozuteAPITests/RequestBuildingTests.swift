import XCTest
@testable import KotozuteAPI

/// リクエストの組み立てとエラー変換。実際に通信せず、送られる中身だけを見る。
final class RequestBuildingTests: XCTestCase {

    /// 認証必須のエンドポイントには Authorization ヘッダが付くこと。
    func testAuthenticatedRequestCarriesBearerToken() async throws {
        let transport = StubTransport(json: #"{"userId":"u1","displayName":"けんと","pairStatus":"none"}"#)
        _ = try await KotozuteClient.stubbed(transport: transport).me()

        let request = try XCTUnwrap(transport.lastRequest)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer dummy-id-token"
        )
    }

    /// GET /invites/{token} は唯一の公開エンドポイント。
    /// 未登録の相手が開く導線なので、トークンを付けてはいけない。
    func testPublicInviteEndpointSendsNoAuthorizationHeader() async throws {
        let transport = StubTransport(json: #"{"inviterDisplayName":"けんと","status":"pending"}"#)
        _ = try await KotozuteClient.stubbed(transport: transport).invite(token: "abc123")

        let request = try XCTUnwrap(transport.lastRequest)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(request.url?.path, "/Prod/invites/abc123")
    }

    /// アーカイブのクエリが仕様どおり組み立てられること。
    func testArchiveQueryItems() async throws {
        let transport = StubTransport(json: #"{"items":[],"nextCursor":null}"#)
        _ = try await KotozuteClient.stubbed(transport: transport)
            .archive(whose: .partner, year: 2026, month: 6, limit: 10, cursor: "opaque==")

        let url = try XCTUnwrap(transport.lastRequest?.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )

        XCTAssertEqual(query["whose"], "partner")
        XCTAssertEqual(query["year"], "2026")
        XCTAssertEqual(query["month"], "6")
        XCTAssertEqual(query["limit"], "10")
        // カーソルは不透明トークン。解釈せずそのまま渡す。
        XCTAssertEqual(query["cursor"], "opaque==")
    }

    /// PATCH は送った項目だけを載せる（未指定は JSON に出さない）。
    func testUpdateMeOmitsUnspecifiedFields() async throws {
        let transport = StubTransport(json: #"{"userId":"u1","displayName":"あたらしい名"}"#)
        _ = try await KotozuteClient.stubbed(transport: transport)
            .updateMe(UpdateMeRequest(displayName: "あたらしい名"))

        let request = try XCTUnwrap(transport.lastRequest)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(json["displayName"] as? String, "あたらしい名")
        XCTAssertNil(json["apnsToken"])
    }

    // MARK: - エラー変換

    /// トークン無し/失効は 401。サインインに戻す判断に使う。
    func testUnauthorizedIsMappedTo401() async throws {
        let transport = StubTransport(statusCode: 401, json: #"{"message":"Unauthorized"}"#)

        do {
            _ = try await KotozuteClient.stubbed(transport: transport).me()
            XCTFail("エラーになるはず")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    /// オープン済みことづての編集は 409。サーバーの error 文言を拾えること。
    func testConflictCarriesServerMessage() async throws {
        let transport = StubTransport(statusCode: 409, json: #"{"error":"already opened"}"#)

        do {
            _ = try await KotozuteClient.stubbed(transport: transport)
                .updateKotozute(id: "k1", body: UpdateKotozuteRequest(body: "書き直し"))
            XCTFail("エラーになるはず")
        } catch let error as APIError {
            XCTAssertEqual(error, .conflict(message: "already opened"))
            XCTAssertEqual(error.serverMessage, "already opened")
        }
    }

    /// 招待は存在しない場合も期限切れも 404。存在有無を漏らさない仕様。
    func testNotFoundForInvite() async throws {
        let transport = StubTransport(statusCode: 404, json: #"{"error":"invite not found"}"#)

        do {
            _ = try await KotozuteClient.stubbed(transport: transport).invite(token: "nope")
            XCTFail("エラーになるはず")
        } catch let error as APIError {
            XCTAssertEqual(error, .notFound(message: "invite not found"))
        }
    }
}
