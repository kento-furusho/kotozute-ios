import Foundation

/// 認証の失敗。Cognito の例外名を、画面で出し分けられる意味に翻訳する。
public enum AuthError: Error, Sendable, Equatable {
    /// メールアドレスかパスワードが違う。
    case invalidCredentials
    /// サインアップ済みだが、まだ確認コードを通していない。確認画面へ誘導する。
    case notConfirmed
    /// そのメールアドレスは既に登録されている。
    case emailAlreadyExists
    /// 確認コードが違う。
    case invalidCode
    /// 確認コードの有効期限切れ。
    case codeExpired
    /// パスワードが要件（8文字以上・小文字・数字）を満たさない。
    case weakPassword(message: String?)
    /// サインインしていない。
    case notSignedIn
    /// リフレッシュも失敗した。再サインインが必要。
    case sessionExpired
    /// Keychain の操作に失敗。
    case keychain(status: OSStatus)
    /// 上記に当てはまらないもの。
    case underlying(message: String)

    /// Cognito が返す例外名から変換する。SDK の型に依存させないため文字列で受ける。
    static func from(exceptionName: String?, message: String?) -> AuthError {
        switch exceptionName {
        case "NotAuthorizedException": .invalidCredentials
        case "UserNotFoundException": .invalidCredentials
        case "UserNotConfirmedException": .notConfirmed
        case "UsernameExistsException": .emailAlreadyExists
        case "CodeMismatchException": .invalidCode
        case "ExpiredCodeException": .codeExpired
        case "InvalidPasswordException": .weakPassword(message: message)
        default: .underlying(message: message ?? exceptionName ?? "不明なエラー")
        }
    }
}
