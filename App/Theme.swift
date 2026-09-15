import SwiftUI
import UIKit

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

    /// 付箋の色（濃いほう）。ここが色の出どころ。
    /// 選択肢も巡回もこれを使うので、増やすと両方に効く。
    static let stickyBaseHexes: [String] = [
        "FFDC72", "B9E6D0", "FFC0AB", "C4DAF6", "DCC8F8", "F7B9CE",
    ]

    /// 巡回の index に対応する16進数。
    static func stickyHex(at index: Int) -> String {
        stickyBaseHexes[index % stickyBaseHexes.count]
    }

    /// 書いた順に巡回させて、並びが単調にならないようにする。
    static let stickyPapers: [StickyPaper] = [
        StickyPaper(light: Color(hex: 0xFFE9A0), base: Color(hex: 0xFFDC72)),
        StickyPaper(light: Color(hex: 0xD2EFE0), base: Color(hex: 0xB9E6D0)),
        StickyPaper(light: Color(hex: 0xFFD6C6), base: Color(hex: 0xFFC0AB)),
        StickyPaper(light: Color(hex: 0xDCE9FB), base: Color(hex: 0xC4DAF6)),
        StickyPaper(light: Color(hex: 0xEFE0FF), base: Color(hex: 0xDCC8F8)),
        // 6色目はもともと5色目とほぼ同じ紫で、隣り合うと見分けがつかなかった。
        // 桃色（3色目）とも違う、赤みの強いピンクにして色相を散らす。
        StickyPaper(light: Color(hex: 0xFBD7E4), base: Color(hex: 0xF7B9CE)),
    ]

    static func stickyPaper(at index: Int) -> StickyPaper {
        stickyPapers[index % stickyPapers.count]
    }

    /// 選ばれた色から紙を作る。
    ///
    /// 保存されているのは1色だけなので、上側の明るい色はここで作る。
    /// 白を少し混ぜて、既定の6色と同じ「上が明るく下が濃い」紙に見せる。
    /// 混ぜないと単色のベタ塗りになり、他の付箋と質感が揃わない。
    ///
    /// 読めない色（16進6桁でないもの）は nil を返す。サーバーが弾いている
    /// はずだが、ここでも落とせるようにしておく。
    static func stickyPaper(hex: String) -> StickyPaper? {
        let trimmed = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else { return nil }
        let base = Color(hex: value)
        return StickyPaper(light: base.mixedWithWhite(0.34), base: base)
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

    /// 白を `amount` のぶんだけ混ぜる。紙の上側の明るい色を作るのに使う。
    ///
    /// SwiftUI の `mix(with:by:)` は iOS 18 から。このアプリは 17 も見るので、
    /// 成分を取り出して自分で混ぜる。
    func mixedWithWhite(_ amount: Double) -> Color {
        let ratio = min(max(amount, 0), 1)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return self
        }
        return Color(
            red: Double(red) + (1 - Double(red)) * ratio,
            green: Double(green) + (1 - Double(green)) * ratio,
            blue: Double(blue) + (1 - Double(blue)) * ratio
        )
    }

    /// 16進6桁に戻す。選んだ色を保存するときに使う。
    /// UIColor 経由で成分を取り出す（Color は成分を直接読めない）。
    var hexString: String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        let channels = components.prefix(3).map { component -> Int in
            Int((min(max(component, 0), 1) * 255).rounded())
        }
        return String(format: "%02X%02X%02X", channels[0], channels[1], channels[2])
    }
}
