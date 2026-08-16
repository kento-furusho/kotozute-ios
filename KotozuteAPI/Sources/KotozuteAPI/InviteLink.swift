import Foundation

/// 招待リンクの形式。
///
///     kotozute://invite/<token>
///
/// 独自スキームにしているのは、Universal Links に必要なドメインと
/// apple-app-site-association をまだ持っていないため。ドメインを用意したら
/// ここに https の解釈を足す（リンクの見た目が良くなり、アプリ未導入でも案内を出せる）。
public enum InviteLink {
    public static let scheme = "kotozute"
    public static let host = "invite"

    public static func url(token: String) -> URL? {
        guard !token.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/\(token)"
        return components.url
    }

    /// リンクからトークンを取り出す。形式が違えば nil。
    /// 未知の URL で誤動作しないよう、スキームとホストの両方を確かめる。
    public static func token(from url: URL) -> String? {
        guard url.scheme == scheme, url.host == host else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        // 余計な階層が付いたものは受け取らない。
        guard parts.count == 1, let token = parts.first, !token.isEmpty else { return nil }
        return token
    }
}
