import Foundation
import KotozuteAPI
import Observation

/// 壁の1週間ぶん。サイクルの区切りで区切る（カレンダーの週ではない）。
struct Week: Identifiable, Equatable {
    /// この週の始まり＝オープンされた時刻。
    let start: Date
    /// 次のオープン。この時刻は含まない。
    let end: Date
    /// 新しい順に 0 から。0 は「いま解禁されている週」。
    let index: Int

    var id: Date { start }
}

/// 壁の読み込み。週ごとにたどる。
///
/// 週の区切りはペアが持っている履歴（cycleStarts）から作る。
/// カレンダーの週で切ると、オープン曜日を変えたときにずれるため。
@Observable
@MainActor
final class WallStore {
    private(set) var weeks: [Week] = []
    private(set) var index = 0
    private(set) var mine: [Kotozute] = []
    private(set) var partner: [Kotozute] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let client: KotozuteClient

    init(client: KotozuteClient) {
        self.client = client
    }

    var current: Week? { weeks.indices.contains(index) ? weeks[index] : nil }
    /// 0 が最新。数字が大きいほど過去。
    var hasNewer: Bool { index > 0 }
    var hasOlder: Bool { index + 1 < weeks.count }

    /// 区切りの履歴から週を組み立てる。
    ///
    /// cycleStarts は古い順。末尾は「いま書いているサイクル」の開始なので、
    /// 壁に出す週は「末尾より前」＝すでにオープンされたものだけ。
    func setCycles(_ starts: [Date]) {
        let sorted = starts.sorted()
        guard sorted.count >= 2 else {
            weeks = []
            return
        }
        var built: [Week] = []
        // 隣り合う2つで1週間。新しい順に並べたいので、あとで反転する。
        for i in 0..<(sorted.count - 1) {
            built.append(Week(start: sorted[i], end: sorted[i + 1], index: 0))
        }
        weeks = built.reversed().enumerated().map {
            Week(start: $1.start, end: $1.end, index: $0)
        }
        index = 0
    }

    func showNewer() async {
        guard hasNewer else { return }
        index -= 1
        await load()
    }

    func showOlder() async {
        guard hasOlder else { return }
        index += 1
        await load()
    }

    /// いま選んでいる週を読む。
    ///
    /// 最新の週（index 0）は相互ロックの対象なので、ここでは読まない。
    /// 画面が this-week の結果をそのまま使う。
    func load() async {
        guard let week = current, week.index > 0 else {
            mine = []
            partner = []
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let mineItems = allPages(whose: .me, in: week)
            async let partnerItems = allPages(whose: .partner, in: week)
            mine = try await mineItems
            partner = try await partnerItems
        } catch {
            mine = []
            partner = []
            errorMessage = "読み込めなかった。"
        }
    }

    /// その週のことづてを最後まで読む。
    ///
    /// サーバーは1回に limit 件までしか返さないので、nextCursor をたどる。
    /// とくに相手の分は、絞り込みが limit のあとに効く都合で、
    /// items が少なくても続きが残っていることがある。件数では打ち切れない。
    private func allPages(whose: ArchiveWhose, in week: Week) async throws -> [Kotozute] {
        var items: [Kotozute] = []
        var cursor: String?
        // 壊れたカーソルで無限に回らないよう、上限を決めておく。
        for _ in 0..<pageLimit {
            let page = try await client.archive(
                whose: whose,
                from: week.start,
                to: week.end,
                limit: pageSize,
                cursor: cursor
            )
            items += page.items
            guard let next = page.nextCursor else { return items }
            cursor = next
        }
        return items
    }
}

/// 1回のリクエストで取る件数。サーバー側の上限に合わせている。
private let pageSize = 50
/// 1週間ぶんで読むページ数の上限。壊れたカーソルで無限に回らないための歯止め。
private let pageLimit = 20
