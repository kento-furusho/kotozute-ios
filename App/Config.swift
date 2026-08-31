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

    /// 規約とプライバシーポリシーの公開先。kotozute リポジトリの web/ を配信している。
    /// App Store の審査では、アプリ内からここへ辿れることを見られる。
    ///
    /// **拡張子は付けない。** Cloudflare の静的アセット配信は .html 付きの
    /// リクエストを拡張子なしへ 307 で正規化するため、付けると毎回
    /// リダイレクトを1回挟むことになる。
    static let termsURL = URL(string: "https://kotozute.app/terms")!
    static let privacyURL = URL(string: "https://kotozute.app/privacy")!
}
