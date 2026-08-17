import Foundation

// バックエンドの Request / Response に対応する型。
// 対応表は kotozute リポジトリの docs/ios-kickoff.md「3. 各エンドポイントの Request / Response」。
//
// 日時は2種類あるので注意する:
//   - createdAt / expiresAt … RFC3339（例 2026-08-11T12:00:00Z）→ Date
//   - nextOpenAt          … 秒もタイムゾーンも無い壁時計（例 2026-08-14T20:00）→ WallClock

// MARK: - POST /users

public struct CreateUserRequest: Encodable, Sendable {
    public let displayName: String
    public let email: String?

    public init(displayName: String, email: String? = nil) {
        self.displayName = displayName
        self.email = email
    }
}

public struct CreateUserResponse: Decodable, Sendable {
    public let userId: String
    public let displayName: String
    public let email: String?
}

// MARK: - GET /me

public enum PairStatus: String, Decodable, Sendable {
    /// まだペアが成立していない。招待導線へ進む。
    case none
    /// ペア成立済み。ホームへ進む。
    case paired
}

public struct MeResponse: Decodable, Sendable {
    public let userId: String
    public let displayName: String
    public let email: String?
    public let pairId: String?
    public let pairStatus: PairStatus
    public let nextOpenAt: WallClock?

    private enum CodingKeys: String, CodingKey {
        case userId, displayName, email, pairId, pairStatus, nextOpenAt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(String.self, forKey: .userId)
        displayName = try c.decode(String.self, forKey: .displayName)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        pairId = try c.decodeIfPresent(String.self, forKey: .pairId)
        pairStatus = try c.decode(PairStatus.self, forKey: .pairStatus)
        nextOpenAt = try WallClock.decodeOptional(from: c, forKey: .nextOpenAt)
    }
}

// MARK: - PATCH /me

public struct UpdateMeRequest: Encodable, Sendable {
    public let displayName: String?
    public let apnsToken: String?

    /// 両方 nil のまま送るとサーバーが 400 を返す。呼び出し側で少なくとも一方を指定すること。
    public init(displayName: String? = nil, apnsToken: String? = nil) {
        self.displayName = displayName
        self.apnsToken = apnsToken
    }
}

public struct UpdateMeResponse: Decodable, Sendable {
    public let userId: String
    public let displayName: String?
    public let apnsToken: String?
}

// MARK: - 招待

public struct CreateInviteResponse: Decodable, Sendable {
    public let token: String
    /// 発行から7日間有効。
    public let expiresAt: Date
}

/// `GET /invites/{token}` は唯一の公開エンドポイント。未登録でも「誰からの招待か」を見られる。
public struct InviteResponse: Decodable, Sendable {
    public let inviterDisplayName: String
    public let status: String
}

public struct AcceptInviteRequest: Encodable, Sendable {
    /// 受諾者が未登録の場合はここで表示名を渡せる。
    public let displayName: String?

    public init(displayName: String? = nil) {
        self.displayName = displayName
    }
}

public struct AcceptInviteResponse: Decodable, Sendable {
    public let pairId: String
}

// MARK: - ペア

public struct Partner: Decodable, Sendable, Hashable {
    public let userId: String
    public let displayName: String
}

public struct PairResponse: Decodable, Sendable {
    public let pairId: String
    public let partner: Partner
    /// 0(日)〜6(土)。
    public let openDayOfWeek: Int
    /// "HH:MM"（2桁）。
    public let openTime: String
    /// IANA タイムゾーン名（例 Asia/Tokyo）。nextOpenAt の解釈にはこれを使う。
    public let timezone: String
    public let status: String
    public let nextOpenAt: WallClock?
    /// サイクルの区切り（古い順）。隣り合う2つが1つの週の範囲になる。
    /// 末尾は「いま書いているサイクル」の開始。
    public let cycleStarts: [Date]

    private enum CodingKeys: String, CodingKey {
        case pairId, partner, openDayOfWeek, openTime, timezone, status, nextOpenAt, cycleStarts
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pairId = try c.decode(String.self, forKey: .pairId)
        partner = try c.decode(Partner.self, forKey: .partner)
        openDayOfWeek = try c.decode(Int.self, forKey: .openDayOfWeek)
        openTime = try c.decode(String.self, forKey: .openTime)
        timezone = try c.decode(String.self, forKey: .timezone)
        status = try c.decode(String.self, forKey: .status)
        nextOpenAt = try WallClock.decodeOptional(from: c, forKey: .nextOpenAt)
        cycleStarts = try c.decodeIfPresent([Date].self, forKey: .cycleStarts) ?? []
    }
}

public struct UpdatePairRequest: Encodable, Sendable {
    public let openDayOfWeek: Int?
    public let openTime: String?
    public let timezone: String?

    public init(openDayOfWeek: Int? = nil, openTime: String? = nil, timezone: String? = nil) {
        self.openDayOfWeek = openDayOfWeek
        self.openTime = openTime
        self.timezone = timezone
    }
}

public struct UpdatePairResponse: Decodable, Sendable {
    public let pairId: String
    public let openDayOfWeek: Int?
    public let openTime: String?
    public let timezone: String?
}

// MARK: - ことづて

/// 一覧に出てくることづて1つ。
public struct Kotozute: Decodable, Sendable, Identifiable, Hashable {
    public let id: String
    public let body: String
    public let createdAt: Date

    public init(id: String, body: String, createdAt: Date) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
    }
}

public struct CreateKotozuteRequest: Encodable, Sendable {
    public let body: String

    public init(body: String) {
        self.body = body
    }
}

public struct CreateKotozuteResponse: Decodable, Sendable {
    public let id: String
    public let body: String
    public let opened: Bool
    public let createdAt: Date
}

public struct UpdateKotozuteRequest: Encodable, Sendable {
    public let body: String

    public init(body: String) {
        self.body = body
    }
}

public struct UpdateKotozuteResponse: Decodable, Sendable {
    public let id: String
    public let body: String
}

// MARK: - GET /kotozute/this-week

public enum OpenStatus: String, Decodable, Sendable {
    /// 相手のことづてがまだオープンされていない。
    case before
    /// 相手のことづてがオープン済み（バッチ解禁済み）。
    case opened
}

/// 直前にオープンされたサイクルの中身。次のオープンまで手元で読める。
public struct LastCycle: Decodable, Sendable {
    /// 自分が書いた分。自分のものなので常に返る。
    public let mine: [Kotozute]
    /// 相手が書いた分。`canSeePartner == false` のときサーバーはこのキー自体を返さない。
    public let partner: [Kotozute]

    private enum CodingKeys: String, CodingKey {
        case mine, partner
    }

    public init(mine: [Kotozute], partner: [Kotozute]) {
        self.mine = mine
        self.partner = partner
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mine = try c.decodeIfPresent([Kotozute].self, forKey: .mine) ?? []
        partner = try c.decodeIfPresent([Kotozute].self, forKey: .partner) ?? []
    }
}

public struct ThisWeekResponse: Decodable, Sendable {
    /// いま書いているサイクルの自分の分。
    public let myKotozute: [Kotozute]
    public let openStatus: OpenStatus
    public let canSeePartner: Bool
    public let lastCycle: LastCycle
    /// 相手がいま書いているサイクルに書いたか。0枚か1枚以上かのみで、枚数は返らない。
    public let partnerHasWritten: Bool
    public let nextOpenAt: WallClock?

    private enum CodingKeys: String, CodingKey {
        case myKotozute, openStatus, canSeePartner, lastCycle, partnerHasWritten, nextOpenAt
    }

    /// プレビューやモックから組み立てるための初期化。
    public init(
        myKotozute: [Kotozute],
        openStatus: OpenStatus,
        canSeePartner: Bool,
        lastCycle: LastCycle,
        partnerHasWritten: Bool,
        nextOpenAt: WallClock?
    ) {
        self.myKotozute = myKotozute
        self.openStatus = openStatus
        self.canSeePartner = canSeePartner
        self.lastCycle = lastCycle
        self.partnerHasWritten = partnerHasWritten
        self.nextOpenAt = nextOpenAt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        myKotozute = try c.decode([Kotozute].self, forKey: .myKotozute)
        openStatus = try c.decode(OpenStatus.self, forKey: .openStatus)
        canSeePartner = try c.decode(Bool.self, forKey: .canSeePartner)
        lastCycle = try c.decodeIfPresent(LastCycle.self, forKey: .lastCycle)
            ?? LastCycle(mine: [], partner: [])
        partnerHasWritten = try c.decode(Bool.self, forKey: .partnerHasWritten)
        nextOpenAt = try WallClock.decodeOptional(from: c, forKey: .nextOpenAt)
    }
}

extension ThisWeekResponse {
    /// 何も無い状態。読み込み前の画面を組むときの土台に使う。
    public static let empty = ThisWeekResponse(
        myKotozute: [],
        openStatus: .before,
        canSeePartner: false,
        lastCycle: LastCycle(mine: [], partner: []),
        partnerHasWritten: false,
        nextOpenAt: nil
    )
}

// MARK: - GET /kotozute/archive

public enum ArchiveWhose: String, Sendable {
    case me
    case partner
}

public struct ArchiveResponse: Decodable, Sendable {
    public let items: [Kotozute]
    /// 次ページのカーソル。中身は不透明なので解釈せず、そのまま次のリクエストに渡す。nil なら終端。
    public let nextCursor: String?
}
