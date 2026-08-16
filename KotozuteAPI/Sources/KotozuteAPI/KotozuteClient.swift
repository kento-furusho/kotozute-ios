import Foundation

/// 認証トークンの供給元。Cognito の実装をこの層から切り離すための境界。
///
/// 本番では AWS SDK for Swift の Cognito から IdToken を返す実装を差し込む。
/// テストでは固定文字列を返すだけのものに置き換えられる。
public protocol TokenProvider: Sendable {
    /// 有効な IdToken(JWT)。失効していれば内部でリフレッシュしてから返すこと。
    func idToken() async throws -> String
}

/// HTTP を実際に投げる部分。テストで差し替えられるように protocol にしておく。
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// URLSession を使う既定の実装。
public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport(message: "HTTP レスポンスではありません")
        }
        return (data, http)
    }
}

/// ことづて API のクライアント。12本のエンドポイントに1対1で対応するメソッドを持つ。
///
/// 自分や相手の ID を URL に載せないのは意図的。サーバーはトークンの `sub` を起点に
/// ペアや相手を解決するので、クライアントが ID を送る必要がない（送っても無視される）。
public struct KotozuteClient: Sendable {
    private let baseURL: URL
    /// 公開エンドポイントだけを叩くクライアントでは nil。
    private let tokenProvider: (any TokenProvider)?
    private let transport: any HTTPTransport

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // createdAt / expiresAt は RFC3339。秒の小数部を付ける実装もあるため両方受ける。
        // nextOpenAt は Date ではなく WallClock なので、この戦略の対象外。
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: raw) { return date }

            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: raw) { return date }

            throw APIError.decoding(message: "日時として解釈できません: \(raw)")
        }
        return decoder
    }()

    /// - Parameters:
    ///   - baseURL: 例 `https://xxxx.execute-api.ap-northeast-1.amazonaws.com/Prod`（末尾スラッシュ無し）
    ///   - tokenProvider: 省略すると公開エンドポイント（`GET /invites/{token}`）専用になる。
    ///     招待リンクを開いた未サインインの相手に「誰からの招待か」を見せる導線で使う。
    public init(
        baseURL: URL,
        tokenProvider: (any TokenProvider)? = nil,
        transport: any HTTPTransport = URLSessionTransport()
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.transport = transport
    }

    // MARK: - ユーザー

    /// 初回プロフィール登録。Cognito はメール/パスワードだけを管理するので、表示名はここで登録する。
    public func createUser(_ body: CreateUserRequest) async throws -> CreateUserResponse {
        try await send(.post, "/users", body: body)
    }

    /// 起動時の起点。`pairStatus` で招待導線かホームかを分ける。
    public func me() async throws -> MeResponse {
        try await send(.get, "/me")
    }

    public func updateMe(_ body: UpdateMeRequest) async throws -> UpdateMeResponse {
        try await send(.patch, "/me", body: body)
    }

    // MARK: - 招待

    public func createInvite() async throws -> CreateInviteResponse {
        try await send(.post, "/invites", body: EmptyBody())
    }

    /// 唯一の公開エンドポイント。未登録の相手が招待リンクを開いたときに使うのでトークンを付けない。
    public func invite(token: String) async throws -> InviteResponse {
        try await send(.get, "/invites/\(escape(token))", authenticated: false)
    }

    public func acceptInvite(
        token: String,
        body: AcceptInviteRequest = AcceptInviteRequest()
    ) async throws -> AcceptInviteResponse {
        try await send(.post, "/invites/\(escape(token))/accept", body: body)
    }

    // MARK: - ペア

    public func pair() async throws -> PairResponse {
        try await send(.get, "/pair")
    }

    public func updatePair(_ body: UpdatePairRequest) async throws -> UpdatePairResponse {
        try await send(.patch, "/pair", body: body)
    }

    // MARK: - ことづて

    public func createKotozute(_ body: CreateKotozuteRequest) async throws -> CreateKotozuteResponse {
        try await send(.post, "/kotozute", body: body)
    }

    /// ホーム画面の中心。相互ロックの判定を内包したレスポンスが返る。
    public func thisWeek() async throws -> ThisWeekResponse {
        try await send(.get, "/kotozute/this-week")
    }

    /// 編集はオープン前・本文のみ。オープン済みなら 409 が返る。
    public func updateKotozute(id: String, body: UpdateKotozuteRequest) async throws -> UpdateKotozuteResponse {
        try await send(.patch, "/kotozute/\(escape(id))", body: body)
    }

    /// アーカイブ。同じ月のなかでカーソルページングする。
    public func archive(
        whose: ArchiveWhose = .me,
        year: Int,
        month: Int,
        limit: Int? = nil,
        cursor: String? = nil
    ) async throws -> ArchiveResponse {
        var query = [
            URLQueryItem(name: "whose", value: whose.rawValue),
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "month", value: String(month)),
        ]
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await send(.get, "/kotozute/archive", query: query)
    }

    // MARK: - 内部

    private enum Method: String {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
    }

    private struct EmptyBody: Encodable {}

    private func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    private func send<Response: Decodable>(
        _ method: Method,
        _ path: String,
        query: [URLQueryItem] = [],
        authenticated: Bool = true
    ) async throws -> Response {
        try await send(method, path, body: Optional<EmptyBody>.none, query: query, authenticated: authenticated)
    }

    private func send<Body: Encodable, Response: Decodable>(
        _ method: Method,
        _ path: String,
        body: Body?,
        query: [URLQueryItem] = [],
        authenticated: Bool = true
    ) async throws -> Response {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.transport(message: "URL を組み立てられません: \(path)")
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else {
            throw APIError.transport(message: "URL を組み立てられません: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.encoder.encode(body)
        }

        if authenticated {
            guard let tokenProvider else {
                throw APIError.unauthorized
            }
            let token = try await tokenProvider.idToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, http): (Data, HTTPURLResponse)
        do {
            (data, http) = try await transport.send(request)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(message: error.localizedDescription)
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = try? Self.decoder.decode(ErrorResponse.self, from: data).error
            throw APIError.from(statusCode: http.statusCode, message: message)
        }

        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(message: String(describing: error))
        }
    }
}
