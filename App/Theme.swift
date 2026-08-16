import SwiftUI

/// 色と書体。docs/design/ の付箋デザイン案から拾っている。
/// トーンは明るい・軽い（ポップ寄り）。
enum Theme {
    static let background = Color(hex: 0xF7F2E9)
    static let ink = Color(hex: 0x3A322C)
    static let inkSoft = Color(hex: 0x8A7B6C)
    static let accent = Color(hex: 0xE4573D)
    static let line = Color(hex: 0xE7DDCD)

    /// 付箋の色。デザイン案は単色ではなく、上が明るく下が濃いグラデーション。
    /// 紙が光を受けている感じが出て、平坦な矩形に見えなくなる。
    /// （docs/design/ の linear-gradient(160deg, 明, 濃) をそのまま写している）
    struct StickyPaper {
        let light: Color
        let base: Color

        var gradient: LinearGradient {
            // 160deg 相当。真上からではなく少し斜めに落とす。
            LinearGradient(
                colors: [light, base],
                startPoint: UnitPoint(x: 0.18, y: 0),
                endPoint: UnitPoint(x: 0.82, y: 1)
            )
        }
    }

    /// 書いた順に巡回させて、並びが単調にならないようにする。
    static let stickyPapers: [StickyPaper] = [
        StickyPaper(light: Color(hex: 0xFFE9A0), base: Color(hex: 0xFFDC72)),
        StickyPaper(light: Color(hex: 0xD2EFE0), base: Color(hex: 0xB9E6D0)),
        StickyPaper(light: Color(hex: 0xFFD6C6), base: Color(hex: 0xFFC0AB)),
        StickyPaper(light: Color(hex: 0xDCE9FB), base: Color(hex: 0xC4DAF6)),
        StickyPaper(light: Color(hex: 0xEFE0FF), base: Color(hex: 0xDCC8F8)),
        StickyPaper(light: Color(hex: 0xE5D8FB), base: Color(hex: 0xD3C0F5)),
    ]

    static func stickyPaper(at index: Int) -> StickyPaper {
        stickyPapers[index % stickyPapers.count]
    }

    /// 単色が要る場所（書く画面の下地など）向け。
    static func stickyColor(at index: Int) -> Color {
        stickyPaper(at: index).base
    }

    /// デザイン案の Zen Maru Gothic は Web フォント。iOS には無いので、
    /// 同じ「丸くてやわらかい」印象を持つシステムフォントの rounded で代替する。
    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
