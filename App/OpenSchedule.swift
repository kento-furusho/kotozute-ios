import Foundation

/// オープンの日時の書き方をまとめる。
///
/// 1箇所に集めているのは、カレンダーの取り違えを繰り返さないため。
/// `Calendar.current` は端末の暦設定に従うので、和暦（`ja_JP@calendar=japanese`）の
/// 端末では 2026 年が 8 年になる。必ずグレゴリオ暦を明示する。
///
/// タイムゾーンもペアの設定に従う。端末の位置ではない。
/// ふたりの「オープンの日」は同じ瞬間を指していないと約束が崩れる。
enum OpenSchedule {
    /// 「8月24日(日) 21:00」
    static func dateTime(_ date: Date, in timezone: TimeZone) -> String {
        formatter(dateFormat: "M月d日(E) HH:mm", in: timezone).string(from: date)
    }

    /// 「8/17 – 8/24」。終わりは次のオープン時刻そのもので、1日前には寄せない。
    static func range(from start: Date, to end: Date, in timezone: TimeZone) -> String {
        let formatter = formatter(dateFormat: "M/d", in: timezone)
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    /// 使い回さず都度作る。DateFormatter は可変なので、タイムゾーンの違う
    /// 画面が1つを共有すると、片方の設定がもう片方に漏れる。
    private static func formatter(dateFormat: String, in timezone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timezone
        formatter.dateFormat = dateFormat
        return formatter
    }
}
