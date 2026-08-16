import SwiftUI

/// 色と書体。docs/design/ の付箋デザイン案から拾っている。
/// トーンは明るい・軽い（ポップ寄り）。
enum Theme {
    static let background = Color(hex: 0xF7F2E9)
    static let ink = Color(hex: 0x3A322C)
    static let inkSoft = Color(hex: 0x8A7B6C)
    static let accent = Color(hex: 0xE4573D)
    static let line = Color(hex: 0xE7DDCD)

    /// 付箋の色。書いた順に巡回させて、並びが単調にならないようにする。
    static let stickyColors: [Color] = [
        Color(hex: 0xFFD84D),
        Color(hex: 0xB9E6D0),
        Color(hex: 0xFFC0AB),
        Color(hex: 0xC4DAF6),
        Color(hex: 0xDCC8F8),
        Color(hex: 0xFFE9A0),
    ]

    static func stickyColor(at index: Int) -> Color {
        stickyColors[index % stickyColors.count]
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
