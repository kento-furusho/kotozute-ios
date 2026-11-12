import Foundation

/// App Store のレビュー依頼を出してよいかの判定。
///
/// 出すのは、オープンして相手のことづてを読み終えたとき（読む画面を閉じた直後）だけ。
/// いちばん気持ちが動いた場面で頼む。読んでいる途中には割り込まない。
///
/// **月に一度まで**（30日あける）。毎週のオープンのたびに出すとしつこくなる。
/// なお OS 側にも上限（1年に3回まで）があり、条件を満たしても出ないことがある。
/// 出たかどうかはアプリから分からないので、「頼んだ日」を記録して間隔を数える。
enum ReviewPrompt {
    static let interval: TimeInterval = 30 * 24 * 60 * 60
    private static let lastRequestedKey = "reviewLastRequestedAt"

    /// 前回頼んだ日から `interval` 以上たっていれば true。一度も頼んでいなければ true。
    static func isDue(lastRequestedAt: Date?, now: Date = Date()) -> Bool {
        guard let lastRequestedAt else { return true }
        return now.timeIntervalSince(lastRequestedAt) >= interval
    }

    /// 間隔があいていれば、頼んだ日として今を記録して true を返す。
    static func claimIfDue(defaults: UserDefaults = .standard, now: Date = Date()) -> Bool {
        let last = defaults.object(forKey: lastRequestedKey) as? Date
        guard isDue(lastRequestedAt: last, now: now) else { return false }
        defaults.set(now, forKey: lastRequestedKey)
        return true
    }
}
