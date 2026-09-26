import Foundation
import KotozuteAPI
import Observation

/// カレンダーの1日ぶん。上段が自分、下段が相手。
struct CalendarDay: Equatable {
    var mine: [Kotozute] = []
    var partner: [Kotozute] = []

    var isEmpty: Bool { mine.isEmpty && partner.isEmpty }
}

/// 「見る」画面のカレンダー表示。1か月ぶんをまとめて読む。
///
/// 週めくり（WallStore）はサイクルの区切りで切るが、こちらは暦の月で切る。
/// 同じことづてを別の切り口で見せるだけなので、サーバーは変えていない。
///
/// **オープン前の相手のことづては、そもそも手元に来ない。**
/// `whose=partner` のアーカイブは `[cycleStarts[0], previousCycleStartedAt)` しか返さないので、
/// まだオープンしていない期間の相手の点は、隠すまでもなく描きようがない。
/// クライアントで伏せる作りにすると、通信を覗けば見えてしまう。
@Observable
@MainActor
final class CalendarStore {
    /// 表示している月の1日（その月のタイムゾーンでの 00:00）。
    private(set) var month: Date = .now
    private(set) var days: [DayKey: CalendarDay] = [:]
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let client: KotozuteClient
    private var timezone = TimeZone(identifier: "Asia/Tokyo") ?? .current

    init(client: KotozuteClient) {
        self.client = client
    }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }

    /// 未来の月へは進ませない。まだ来ていない月に用は無い。
    var hasNewer: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { return false }
        return next <= startOfMonth(for: .now)
    }

    func start(timezone: TimeZone) async {
        self.timezone = timezone
        if days.isEmpty {
            month = startOfMonth(for: .now)
            await load()
        }
    }

    func showPreviousMonth() async {
        guard let previous = calendar.date(byAdding: .month, value: -1, to: month) else { return }
        month = previous
        await load()
    }

    func showNextMonth() async {
        guard hasNewer, let next = calendar.date(byAdding: .month, value: 1, to: month) else { return }
        month = next
        await load()
    }

    func day(_ date: Date) -> CalendarDay {
        days[DayKey(date, in: calendar)] ?? CalendarDay()
    }

    func reload() async {
        await load()
    }

    /// 表示している月ぶんを、自分と相手ぶん読む。
    ///
    /// `year`/`month` ではなく `from`/`to` で引く。サーバーは SK（UTC の文字列）で
    /// 範囲を切るので、月の境目は**このペアのタイムゾーンの月初**でなければ1日ずれる。
    private func load() async {
        guard let end = calendar.date(byAdding: .month, value: 1, to: month) else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let mineItems = allPages(whose: .me, from: month, to: end)
            async let partnerItems = allPages(whose: .partner, from: month, to: end)
            days = group(mine: try await mineItems, partner: try await partnerItems)
        } catch {
            days = [:]
            errorMessage = "読み込めなかった。"
        }
    }

    private func group(mine: [Kotozute], partner: [Kotozute]) -> [DayKey: CalendarDay] {
        var grouped: [DayKey: CalendarDay] = [:]
        let calendar = calendar
        for item in mine {
            grouped[DayKey(item.createdAt, in: calendar), default: CalendarDay()].mine.append(item)
        }
        for item in partner {
            grouped[DayKey(item.createdAt, in: calendar), default: CalendarDay()].partner.append(item)
        }
        // 1日の中は書いた順に並べる。付箋の並びと時刻の並びを揃えるため。
        for key in grouped.keys {
            grouped[key]?.mine.sort { $0.createdAt < $1.createdAt }
            grouped[key]?.partner.sort { $0.createdAt < $1.createdAt }
        }
        return grouped
    }

    /// 最後まで読む。WallStore と同じ理由で、件数では打ち切れない
    /// （相手の分は絞り込みが limit のあとに効くので、少なくても続きが残る）。
    private func allPages(whose: ArchiveWhose, from: Date, to: Date) async throws -> [Kotozute] {
        var items: [Kotozute] = []
        var cursor: String?
        for _ in 0..<monthPageLimit {
            let page = try await client.archive(
                whose: whose,
                from: from,
                to: to,
                limit: monthPageSize,
                cursor: cursor
            )
            items += page.items
            guard let next = page.nextCursor else { return items }
            cursor = next
        }
        return items
    }

    private func startOfMonth(for date: Date) -> Date {
        let calendar = calendar
        let parts = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: parts) ?? date
    }
}

/// 日付をそのまま鍵にすると時刻ぶんだけ別物になるので、年月日だけ取り出す。
struct DayKey: Hashable {
    let year: Int
    let month: Int
    let day: Int

    init(_ date: Date, in calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        year = parts.year ?? 0
        month = parts.month ?? 0
        day = parts.day ?? 0
    }
}

private let monthPageSize = 50
/// 1か月ぶんで読むページ数の上限。壊れたカーソルで無限に回らないための歯止め。
private let monthPageLimit = 20
