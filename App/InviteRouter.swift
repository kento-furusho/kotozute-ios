import Foundation
import KotozuteAPI
import Observation

/// 受け取った招待をアプリ全体で持ち回る。
///
/// 招待は「まだサインインしていない相手」が開くことがあるので、認証の外側に置く。
/// サインインが済むまでトークンを抱えておき、済んだところで受諾に進む。
@Observable
@MainActor
final class InviteRouter {
    /// これから受ける招待のトークン。
    private(set) var pendingToken: String?
    /// 「誰からの招待か」。公開エンドポイントで取れるので、未サインインでも出せる。
    private(set) var preview: InviteResponse?
    private(set) var errorMessage: String?
    private(set) var isLoading = false

    func open(url: URL) {
        // 解析は KotozuteAPI の InviteLink（テスト済み）に任せる。
        guard let token = InviteLink.token(from: url) else { return }
        accept(token: token)
    }

    /// シミュレータでの確認用。独自スキームのリンクは iOS が確認ダイアログを出し、
    /// タップが要るため、起動引数で同じ状態を作れるようにしておく。
    ///   xcrun simctl launch <udid> dev.kotozute.app --invite <token>
    func seedFromLaunchArguments() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--invite"), index + 1 < arguments.count else { return }
        accept(token: arguments[index + 1])
        #endif
    }

    /// コードを直接受け取る（リンクが踏めなかったとき用の入口）。
    func accept(token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pendingToken = trimmed
        preview = nil
        errorMessage = nil
        Task { await loadPreview() }
    }

    func clear() {
        pendingToken = nil
        preview = nil
        errorMessage = nil
    }

    /// 「◯◯からの招待」を取りに行く。トークン不要の公開エンドポイント。
    private func loadPreview() async {
        guard let pendingToken else { return }
        isLoading = true
        defer { isLoading = false }

        // 認証を持たないクライアント。公開エンドポイント以外は呼べない。
        let client = KotozuteClient(baseURL: Config.apiBaseURL)
        do {
            preview = try await client.invite(token: pendingToken)
        } catch APIError.notFound {
            // 存在しない場合も期限切れも 404。区別せずに伝える（サーバーも区別しない）。
            errorMessage = "この招待は使えません。\n期限が切れている可能性があります。\n\n招待した方に、\n新しいリンクを送ってもらってください。"
        } catch {
            errorMessage = "招待を読み込めなかった。"
        }
    }
}
