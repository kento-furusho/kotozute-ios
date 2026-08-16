import Foundation

/// `nextOpenAt` 用の型。`2026-08-14T20:00` のように**秒もタイムゾーンも持たない**文字列で返ってくる。
///
/// サーバー側は `Format("2006-01-02T15:04")` で組み立てており、これは絶対時刻ではなく
/// 「ペアのタイムゾーンにおける壁時計の時刻」を表す。`Date` に素直に変換すると
/// どのタイムゾーンで解釈するかの情報が失われるため、生の文字列を保持したうえで
/// 変換にはタイムゾーンを明示的に要求する。
///
/// パースに失敗しても値自体は保持する。日時ひとつのために
/// レスポンス全体のデコードを落とさないための判断。
public struct WallClock: Sendable, Hashable, Codable {
    /// サーバーから来た文字列そのまま。
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// 指定したタイムゾーンで解釈して `Date` に変換する。形式が不正なら nil。
    ///
    /// タイムゾーンはペアの設定（`GET /pair` の `timezone`）を渡すのが正しい。
    public func date(in timeZone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let parts = rawValue.split(separator: "T")
        guard parts.count == 2 else { return nil }

        let ymd = parts[0].split(separator: "-")
        let hm = parts[1].split(separator: ":")
        guard ymd.count == 3, hm.count == 2,
              let year = Int(ymd[0]), let month = Int(ymd[1]), let day = Int(ymd[2]),
              let hour = Int(hm[0]), let minute = Int(hm[1])
        else { return nil }

        return calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))
    }
}

extension WallClock {
    /// 空文字を nil に畳む。ペア未成立のとき `nextOpenAt` は省略ではなく `""` で返るため
    /// （`functions/get-this-week/main.go`）、その揺れをここで吸収する。
    static func decodeOptional<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        forKey key: K
    ) throws -> WallClock? {
        guard let raw = try container.decodeIfPresent(String.self, forKey: key), !raw.isEmpty else {
            return nil
        }
        return WallClock(raw)
    }
}
