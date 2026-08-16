import Foundation
import KotozuteAPI
import Observation

/// 画面が必要とする状態をまとめて持つ。API から取ってくる係。
@Observable
@MainActor
final class KotozuteStore {
    enum Phase: Equatable {
        case loading
        /// Cognito のユーザーはいるが、まだ表示名を登録していない（GET /me が 404）。
        case needsProfile
        /// ペア未成立。招待の導線へ。
        case noPair
        case ready
        case failed(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var myKotozute: [Kotozute] = []
    private(set) var homeState: HomeState?
    private(set) var partnerName = ""
    private(set) var timezone = TimeZone(identifier: "Asia/Tokyo") ?? .current
    private(set) var inviteToken: String?

    /// nil のときは通信せず、手元の値だけで動く（起動引数での画面確認用）。
    private let client: KotozuteClient?

    init(client: KotozuteClient?) {
        self.client = client
        if client == nil { seedFromLaunchArguments() }
    }

    // MARK: - 読み込み

    func load() async {
        guard let client else { return }
        phase = .loading
        do {
            // 1. 自分の情報。未登録なら 404 が返るので、表示名の登録へ回す。
            let me: MeResponse
            do {
                me = try await client.me()
            } catch APIError.notFound {
                phase = .needsProfile
                return
            }

            guard me.pairStatus == .paired else {
                phase = .noPair
                return
            }

            // 2. 相手の名前とタイムゾーン。nextOpenAt の解釈にタイムゾーンが要る。
            let pair = try await client.pair()
            partnerName = pair.partner.displayName
            timezone = TimeZone(identifier: pair.timezone) ?? timezone

            // 3. 今週の状態。相互ロックの判定はここに入っている。
            let thisWeek = try await client.thisWeek()
            myKotozute = thisWeek.myKotozute
            homeState = HomeState(from: thisWeek)
            phase = .ready
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    func registerProfile(displayName: String) async {
        guard let client else { return }
        do {
            _ = try await client.createUser(CreateUserRequest(displayName: displayName))
            await load()
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    func createInvite() async {
        guard let client else { return }
        do {
            inviteToken = try await client.createInvite().token
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    func write(_ body: String) async {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let client else {
            // 通信しないモード。手元の配列を更新して画面の動きだけ確かめる。
            myKotozute.append(Kotozute(id: UUID().uuidString, body: trimmed, createdAt: Date()))
            rebuildDemoState()
            return
        }

        do {
            _ = try await client.createKotozute(CreateKotozuteRequest(body: trimmed))
            // 書くと相互ロックが外れることがあるので、状態を取り直す。
            await load()
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: any Error) -> String {
        guard let error = error as? APIError else { return error.localizedDescription }
        return switch error {
        case .unauthorized: "サインインし直してほしい。"
        case .conflict: "いまはその操作ができない。"
        case let .transport(message): "通信に失敗した。\(message)"
        default: error.serverMessage ?? "うまくいかなかった。"
        }
    }

    // MARK: - 通信しないモード

    private var demoPartner: [Kotozute] = []
    private var demoPartnerOpened = false

    private func seedFromLaunchArguments() {
        partnerName = "あい"
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--demo-state"), index + 1 < arguments.count {
            switch arguments[index + 1] {
            case "waiting": seedMine(); seedPartner()
            case "locked": seedPartner(); demoPartnerOpened = true
            case "visible": seedMine(); seedPartner(); demoPartnerOpened = true
            default: break
            }
        }
        rebuildDemoState()
        phase = .ready
    }

    private func seedMine() {
        myKotozute = [
            Kotozute(
                id: "m1",
                body: "急いでたのに駅まで送ってくれた。助かった。",
                createdAt: Date().addingTimeInterval(-86_400 * 3)
            )
        ]
    }

    private func seedPartner() {
        demoPartner = [
            Kotozute(
                id: "p1",
                body: "洗い物、いつのまにか終わってた。ありがとう。",
                createdAt: Date().addingTimeInterval(-86_400 * 2)
            ),
            Kotozute(
                id: "p2",
                body: "朝、無言でコーヒー出てきたの助かった",
                createdAt: Date().addingTimeInterval(-86_400)
            ),
        ]
    }

    /// サーバーの buildThisWeekResponse と同じ規則で組み立てる。
    private func rebuildDemoState() {
        let canSeePartner = !myKotozute.isEmpty && demoPartnerOpened
        homeState = HomeState(from: ThisWeekResponse(
            myKotozute: myKotozute,
            openStatus: demoPartnerOpened ? .opened : .before,
            canSeePartner: canSeePartner,
            lastCycle: LastCycle(mine: [], partner: canSeePartner ? demoPartner : []),
            partnerHasWritten: !demoPartner.isEmpty,
            nextOpenAt: WallClock("2026-08-21T20:00")
        ))
    }
}
