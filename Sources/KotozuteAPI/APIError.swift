import Foundation

/// API 呼び出しの失敗。HTTP のステータスコードを、画面が分岐しやすい意味に翻訳する。
///
/// サーバーはエラー時に `{"error": "..."}` を返すので、その文言を `message` に載せる。
public enum APIError: Error, Sendable, Equatable {
    /// 400。リクエストの内容が不正。
    case badRequest(message: String?)
    /// 401。トークンが無い/失効している。API Gateway が Lambda に到達させず弾いた状態。
    /// サインイン画面に戻すか、リフレッシュトークンで再取得する。
    case unauthorized
    /// 404。見つからない。招待では「存在しない」と「期限切れ」を区別せず返る（存在有無を漏らさないため）。
    case notFound(message: String?)
    /// 409。状態が競合。例: 登録済みユーザーの再登録、ペア成立済み、オープン済みことづての編集。
    case conflict(message: String?)
    /// その他のステータス。
    case unexpectedStatus(code: Int, message: String?)
    /// 通信そのものの失敗。
    case transport(message: String)
    /// レスポンスの形が想定と違う。
    case decoding(message: String)

    /// サーバーが返した `error` フィールドの文言（あれば）。
    public var serverMessage: String? {
        switch self {
        case let .badRequest(message), let .notFound(message), let .conflict(message):
            return message
        case let .unexpectedStatus(_, message):
            return message
        case .unauthorized:
            return nil
        case let .transport(message), let .decoding(message):
            return message
        }
    }

    static func from(statusCode: Int, message: String?) -> APIError {
        switch statusCode {
        case 400: .badRequest(message: message)
        case 401, 403: .unauthorized
        case 404: .notFound(message: message)
        case 409: .conflict(message: message)
        default: .unexpectedStatus(code: statusCode, message: message)
        }
    }
}

/// エラー時のレスポンスボディ。
struct ErrorResponse: Decodable {
    let error: String
}
