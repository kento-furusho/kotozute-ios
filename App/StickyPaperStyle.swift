import SwiftUI

/// 付箋の「紙」の見た目。本文の有無に関わらず共通なので、修飾として切り出している。
///
/// docs/design/ の作り込み案から4つの要素を写している:
///   - 上が明るく下が濃いグラデーション（紙が光を受けている感じ）
///   - ほぼ直角の角。付箋は角丸ではない
///   - 下に落ちる柔らかい影（浮いて見せる）
///   - 上端の内側に白い線（紙の厚みの縁）
/// さらにマスキングテープで「貼ってある」ことを示す。
extension View {
    func stickyPaper(
        _ paper: Theme.StickyPaper,
        tilt: Double,
        tapeTilt: Double = -1.5,
        isLarge: Bool = false
    ) -> some View {
        modifier(StickyPaperStyle(paper: paper, tilt: tilt, tapeTilt: tapeTilt, isLarge: isLarge))
    }
}

struct StickyPaperStyle: ViewModifier {
    let paper: Theme.StickyPaper
    let tilt: Double
    var tapeTilt: Double = -1.5
    var isLarge: Bool = false

    func body(content: Content) -> some View {
        content
            .background(paper.gradient)
            // 紙の厚みに見える縁。クリップの内側に入れる。
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.white.opacity(0.5))
                    .frame(height: 1)
            }
            // 付箋の角はほぼ直角。角丸にするとカードに見えてしまう。
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .shadow(color: Theme.ink.opacity(0.28), radius: 9, x: 0, y: 7)
            // テープはクリップの外。付箋からはみ出して貼られている。
            .overlay(alignment: .top) { tape.offset(y: isLarge ? -11 : -7) }
            .rotationEffect(.degrees(tilt))
    }

    /// マスキングテープ。半透明の白に、両端だけ破線を入れて切り口を出す。
    private var tape: some View {
        Rectangle()
            .fill(.white.opacity(0.62))
            .frame(width: isLarge ? 74 : 46, height: isLarge ? 26 : 17)
            .overlay(alignment: .leading) { tapeEdge }
            .overlay(alignment: .trailing) { tapeEdge }
            .shadow(color: .black.opacity(0.09), radius: 1, y: 1)
            .rotationEffect(.degrees(tapeTilt))
    }

    private var tapeEdge: some View {
        Rectangle()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            .foregroundStyle(.black.opacity(0.08))
            .frame(width: 1)
    }
}

/// 枠だけのボタン。画面の下に並ぶ導線を、押せるものとして見せる。
///
/// 塗りつぶしは主役のボタン（「リンクを送る」など）に取ってあるので、
/// ここは枠だけにして、主役と並んだときに序列が崩れないようにする。
struct OutlineButtonStyle: ButtonStyle {
    var tint: Color = Theme.inkSoft

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(15, weight: .medium))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(.white.opacity(configuration.isPressed ? 0.4 : 0.7))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
    }
}
