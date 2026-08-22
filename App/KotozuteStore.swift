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
    /// 自分の表示名。相手の画面では「◯◯からのことづて」の◯◯になる。
    private(set) var myName = ""
    private(set) var partnerName = ""
    private(set) var timezone = TimeZone(identifier: "Asia/Tokyo") ?? .current
    /// オープンの曜日（0=日〜6=土）と時刻（"HH:MM"）。設定画面で変える。
    private(set) var openDayOfWeek = 5
    private(set) var openTime = "20:00"
    /// サイクルの区切り（古い順）。壁を週ごとにたどるのに使う。
    private(set) var cycleStarts: [Date] = []
    private(set) var inviteToken: String?
    private(set) var isAccepting = false
    private(set) var acceptError: String?

    /// サーバーに送り終えた端末トークン。同じものを何度も送らないための覚え。
    private var sentPushToken: String?

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

            myName = me.displayName

            guard me.pairStatus == .paired else {
                // ペア成立前に書いた分も、招待画面で見せたいので取っておく。
                // サーバーはペア未成立でも自分のことづてを返す（相手に関する値は空）。
                // 取れなくても招待は進められるので、失敗しても止めない。
                if let thisWeek = try? await client.thisWeek() {
                    myKotozute = thisWeek.myKotozute
                }
                phase = .noPair
                return
            }

            // 2. 相手の名前とタイムゾーン。nextOpenAt の解釈にタイムゾーンが要る。
            let pair = try await client.pair()
            partnerName = pair.partner.displayName
            timezone = TimeZone(identifier: pair.timezone) ?? timezone
            openDayOfWeek = pair.openDayOfWeek
            openTime = pair.openTime
            cycleStarts = pair.cycleStarts

            // 3. 今週の状態。相互ロックの判定はここに入っている。
            let thisWeek = try await client.thisWeek()
            myKotozute = thisWeek.myKotozute
            homeState = HomeState(from: thisWeek)
            phase = .ready
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    /// 端末トークンをサーバーへ渡す。サーバーはこれを SNS のエンドポイントに変えて保存する。
    ///
    /// トークンは OS から降ってくるタイミングが読めないので、取れているときに何度でも
    /// 呼んでよいようにしてある。同じものは送らない。
    /// 失敗しても画面には出さない。通知が無くてもアプリは成り立つし、
    /// アプリを開くたびに送り直す機会がある。
    func syncPushToken(_ token: String?) async {
        guard let client, let token, !token.isEmpty, token != sentPushToken else { return }
        do {
            _ = try await client.updateMe(UpdateMeRequest(apnsToken: token))
            sentPushToken = token
        } catch {
            print("端末トークンを送れなかった: \(error)")
        }
    }

    /// 表示名を変える。エラー文言を返す（nil なら成功）。
    ///
    /// 空や長すぎる名前はサーバーが 400 で弾く。ここでも空だけは先に見て、
    /// 押しても何も起きないボタンにしない。
    func updateDisplayName(_ name: String) async -> String? {
        guard let client else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "なまえを入れてほしい。" }
        guard trimmed != myName else { return nil }
        do {
            _ = try await client.updateMe(UpdateMeRequest(displayName: trimmed))
            myName = trimmed
            return nil
        } catch {
            return Self.message(for: error)
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

    /// 招待を受けてペアを成立させる。成立したら状態を取り直してホームへ進む。
    func acceptInvite(token: String) async {
        guard let client else { return }
        isAccepting = true
        acceptError = nil
        defer { isAccepting = false }
        do {
            _ = try await client.acceptInvite(token: token)
            await load()
        } catch APIError.conflict {
            acceptError = "この招待はもう使えない。期限切れか、すでに使われている。"
        } catch APIError.badRequest {
            acceptError = "自分の招待は受けられない。"
        } catch {
            acceptError = Self.message(for: error)
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
            // ペア未成立でも書ける（ことづては書いた人の下に保存される）。
            _ = try await client.createKotozute(CreateKotozuteRequest(body: trimmed))
            // 書くと相互ロックが外れることがあるので、状態を取り直す。
            await load()
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    /// 本文の書き直し。書くサイクルのものだけ通る。
    /// オープン済みならサーバーが 409 を返すので、その旨を伝えて状態を取り直す。
    func edit(id: String, body: String) async -> String? {
        guard let client else { return nil }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        do {
            _ = try await client.updateKotozute(id: id, body: UpdateKotozuteRequest(body: trimmed))
            await load()
            return nil
        } catch APIError.conflict {
            await load()
            return "オープン済みのことづては書き直せない。"
        } catch {
            return Self.message(for: error)
        }
    }

    /// オープンの曜日・時刻を変える。成功したら状態を取り直して次回オープン日を更新する。
    func updateSchedule(openDayOfWeek: Int, openTime: String) async -> String? {
        guard let client else { return nil }
        do {
            _ = try await client.updatePair(
                UpdatePairRequest(openDayOfWeek: openDayOfWeek, openTime: openTime)
            )
            await load()
            return nil
        } catch {
            return Self.message(for: error)
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
