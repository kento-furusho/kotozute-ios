import Foundation

/// 招待リンクの形式。2つを受け付ける。
///
///     https://kotozute.app/invite/<token>   ← 送るのはこちら（ユニバーサルリンク）
///     kotozute://invite/<token>              ← 古い形。前に送られたリンクのために残す
///
/// https の形にしたのは、独自スキームのリンクが LINE やメッセージで押せる形にならず、
/// アプリが入っていない人が押しても何も起きなかったため。https なら
/// アプリがあればアプリで開き、無ければ kotozute.app の招待ページが開いて App Store へ案内できる。
/// アプリで開くには、kotozute.app に apple-app-site-association を置き、
/// アプリに Associated Domains（applinks:kotozute.app）を付ける必要がある。
public enum InviteLink {
    public static let scheme = "kotozute"
    public static let host = "invite"
    public static let webHost = "kotozute.app"

    /// 送るためのリンク（https）。
    public static func url(token: String) -> URL? {
        guard !token.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = webHost
        components.path = "/invite/\(token)"
        return components.url
    }

    /// リンクからトークンを取り出す。形式が違えば nil。
    /// 未知の URL で誤動作しないよう、スキームとホストの両方を確かめる。
    public static func token(from url: URL) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        let candidate: String?
        switch (url.scheme, url.host) {
        case ("https", webHost):
            // /invite/<token> だけを受け取る。ほかのページの URL では動かない。
            guard parts.count == 2, parts[0] == "invite" else { return nil }
            candidate = parts[1]
        case (scheme, host):
            guard parts.count == 1 else { return nil }
            candidate = parts.first
        default:
            return nil
        }
        guard let token = candidate, !token.isEmpty else { return nil }
        return token
    }
}
