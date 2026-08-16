import Foundation
@testable import KotozuteAPI

/// 固定のレスポンスを返し、送られたリクエストを記録するだけのトランスポート。
/// 実際の通信をせずに、URL の組み立て・ヘッダ・デコードまでを検証するために使う。
final class StubTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [URLRequest] = []
    private let statusCode: Int
    private let body: Data

    var requests: [URLRequest] {
        lock.withLock { _requests }
    }

    var lastRequest: URLRequest? {
        lock.withLock { _requests.last }
    }

    init(statusCode: Int = 200, json: String = "{}") {
        self.statusCode = statusCode
        self.body = Data(json.utf8)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { _requests.append(request) }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (body, response)
    }
}

struct StubTokenProvider: TokenProvider {
    let token: String

    init(token: String = "dummy-id-token") {
        self.token = token
    }

    func idToken() async throws -> String { token }
}

extension KotozuteClient {
    /// テスト用の組み立て。ベース URL は実物と同じ形（末尾にステージ名が付く）にしておく。
    static func stubbed(transport: StubTransport) -> KotozuteClient {
        KotozuteClient(
            baseURL: URL(string: "https://example.execute-api.ap-northeast-1.amazonaws.com/Prod")!,
            tokenProvider: StubTokenProvider(),
            transport: transport
        )
    }
}
