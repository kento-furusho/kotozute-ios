import KotozuteAPI
import SwiftUI

/// fullScreenCover(item:) に渡すための入れ物。
/// 配列そのものは Identifiable にできないので、包んで id を持たせる。
struct RevealItems: Identifiable {
    let id = UUID()
    let items: [Kotozute]
}

/// オープンの瞬間。週に一度だけ出る画面。
///
/// デザイン案（10-reveal）に合わせている:
///   - 付箋がぼかしから現れる（blur 6px → 0）
///   - 光の粒がひとつずつ灯る
///   - タイトルは名詞のみ（「今週のことづて」）
///   - 「1枚ずつ読む」で読む画面へ
///
/// この画面は同じサイクルで一度しか出さない。毎回出ると演出が飾りになる。
struct RevealView: View {
    let partnerName: String
    let items: [Kotozute]
    /// 「1枚ずつ読む」。閉じてから読む画面へ。
    let onRead: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var revealed = false
    @State private var sparklePhase = 0.0

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 48)

            ZStack {
                notes
                sparkles
            }
            .padding(.top, 36)

            Spacer(minLength: 24)

            Button {
                dismiss()
                onRead()
            } label: {
                Text("1枚ずつ読む")
                    .font(Theme.font(17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 28)

            Button("とじる") { dismiss() }
                .font(Theme.font(14))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 14)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .task {
            // 開いた瞬間ではなく、ひと呼吸おいてから晴らす。
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.easeOut(duration: 1.1)) { revealed = true }

            // 灯してから消す。出しっぱなしにすると飾りとして残ってしまう。
            withAnimation(.easeOut(duration: 0.6)) { sparklePhase = 1 }
            try? await Task.sleep(for: .milliseconds(1100))
            withAnimation(.easeIn(duration: 0.7)) { sparklePhase = 0 }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("OPEN")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Theme.accent.opacity(0.12))
                .clipShape(Capsule())

            // タイトルは名詞のみ。「オープンしました」のような文にしない。
            Text("今週のことづて")
                .font(Theme.font(28, weight: .bold))
                .foregroundStyle(Theme.ink)

            // 見出しが「今週のことづて」なので、ここは誰のものかと、
            // 読める状態になったことだけを言う。
            Text("\(partnerName)のことづてが読めるようになりました")
                .font(Theme.font(14))
                .foregroundStyle(Theme.inkSoft)
        }
        .opacity(revealed ? 1 : 0)
        .animation(.easeOut(duration: 0.5), value: revealed)
    }

    /// ぼかしから現れる付箋。中身はまだ読ませない（読むのは次の画面）。
    private var notes: some View {
        StickyNoteList(items: Array(items.prefix(4)), colorOffset: 2)
            .padding(.horizontal, 24)
            .blur(radius: revealed ? 0 : 6)
            .scaleEffect(revealed ? 1 : 0.96)
            .opacity(revealed ? 1 : 0.6)
    }

    /// 光の粒。位置は固定にして、毎回同じ見え方にする（乱数だとぶれる）。
    private var sparkles: some View {
        ZStack {
            ForEach(Array(Self.positions.enumerated()), id: \.offset) { index, point in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, .white.opacity(0.85), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 9
                        )
                    )
                    .frame(width: 18, height: 18)
                    .scaleEffect(0.2 + 0.8 * sparklePhase)
                    // ひとつずつ灯って、ゆっくり消える。
                    .opacity(sparklePhase)
                    .offset(x: point.x, y: point.y)
                    .animation(
                        .easeInOut(duration: 0.9).delay(Double(index) * 0.12),
                        value: sparklePhase
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private static let positions: [CGPoint] = [
        CGPoint(x: -110, y: -60),
        CGPoint(x: 96, y: -28),
        CGPoint(x: -48, y: 42),
        CGPoint(x: 118, y: 76),
        CGPoint(x: -122, y: 110),
    ]
}
