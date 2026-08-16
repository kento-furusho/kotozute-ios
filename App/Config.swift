import Foundation

/// バックエンドの接続先。SAM の Outputs から取った値。
///
/// Cognito のクライアント ID とユーザープール ID は秘密情報ではない。
/// iOS のような公開クライアントはシークレットを持てない（アプリに埋め込んだ値は
/// 取り出せる）ため、シークレット無しのクライアントとして作ってある。
enum Config {
    static let apiBaseURL = URL(string: "https://fce7tbbiq5.execute-api.ap-northeast-1.amazonaws.com/Prod")!
    static let userPoolClientId = "1hbuhnvdap6ah8e9tcs5elnuq"
    static let region = "ap-northeast-1"
}
