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
    static let supportURL = URL(string: "https://kotozute.app/support")!
    /// App Store の直リンク。招待の文面に入れて、相手がアプリを入手できるようにする。
    static let appStoreURL = URL(string: "https://apps.apple.com/jp/app/id6807755962")!

    /// 問題を報告するためのメール。
    ///
    /// App Store のガイドライン 1.2 は、ユーザーが書いたものを他のユーザーに
    /// 見せるアプリに「不適切な内容を報告する手段」を求めている。
    /// ことづては招待した相手としか交換しないが、手段が無いこと自体を
    /// 理由に差し戻されることがあるので置いておく。
    ///
    /// 調べるのに要る情報（版と自分のID）を本文に入れておく。
    /// 送る前に本人が消せるよう、メールの下書きに置くだけにする。
    static func reportMailURL(userID: String) -> URL {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let body = """
        （こちらにお困りの内容をご記入ください）



        ――――――――――
        以下は確認のための情報です。消さずにそのまま送信してください。
        アプリのバージョン：\(version)（\(build)）
        ユーザーID：\(userID)
        """
        var components = URLComponents(string: "mailto:support@kotozute.app")!
        components.queryItems = [
            URLQueryItem(name: "subject", value: "ことづて 問題の報告"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url ?? URL(string: "mailto:support@kotozute.app")!
    }
}
