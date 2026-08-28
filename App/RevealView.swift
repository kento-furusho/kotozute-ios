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
    /// 実際にオープンを押したときに呼ぶ。
    /// この回を「見た」と記録するのはここ。押さずに閉じた人には、次にまた出す
    /// （週に一度きりの場面なので、開かずに消えたことにしない）。
    var onOpened: () -> Void = {}
    /// 「1枚ずつ読む」。閉じてから読む画面へ。
    let onRead: () -> Void

    @Environment(\.dismiss) private var dismiss
    /// 晴れ方の段階。0=ぼかし／1=うっすら形が見える／2=くっきり。
    ///
    /// 一息で晴らすと「切り替わった」だけになる。途中に一段はさむと、
    /// 近づいていく時間ができる。
    @State private var stage = 0
    /// 見出しは開いた直後に出す。晴らすかどうかは本人に任せる。
    @State private var headerShown = false
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

            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .task {
            // 見出しだけ先に出す。付箋はぼかしたまま、押されるのを待つ。
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.easeOut(duration: 0.5)) { headerShown = true }
        }
    }

    /// オープンを押すまでは晴らさない。週に一度の場面を、本人の操作で始めてもらう。
    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 0) {
            if stage == 2 {
                Button {
                    dismiss()
                    onRead()
                } label: {
                    primaryLabel("1枚ずつ読む")
                }
            } else {
                Button(action: open) {
                    primaryLabel("オープンする")
                }
                // 晴らしている最中の二度押しを防ぐ。
                .disabled(stage != 0)
                .opacity(stage == 0 ? 1 : 0.5)
            }

            Button("とじる") { dismiss() }
                .font(Theme.font(14))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 14)
                .padding(.bottom, 28)
        }
        .padding(.horizontal, 28)
    }

    private func primaryLabel(_ title: String) -> some View {
        Text(title)
            .font(Theme.font(17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accent)
            .clipShape(Capsule())
    }

    private func open() {
        onOpened()
        Task {
            // 一段目。付箋の形と色がうっすら分かるところまで。
            withAnimation(.easeOut(duration: 0.7)) { stage = 1 }
            withAnimation(.easeOut(duration: 0.6)) { sparklePhase = 1 }

            // 間をおいてから二段目。ここで初めて読める。
            try? await Task.sleep(for: .milliseconds(950))
            withAnimation(.easeOut(duration: 0.9)) { stage = 2 }

            // 灯してから消す。出しっぱなしにすると飾りとして残ってしまう。
            try? await Task.sleep(for: .milliseconds(700))
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
        .opacity(headerShown ? 1 : 0)
    }

    /// ぼかしから現れる付箋。押されてから二段階で晴らす。
    /// 一段目では形と色だけ、二段目で文字が読めるようになる。
    private var notes: some View {
        StickyNoteList(items: Array(items.prefix(4)), colorOffset: 2)
            .padding(.horizontal, 24)
            .blur(radius: blurRadius)
            .scaleEffect(scale)
            .opacity(noteOpacity)
    }

    private var blurRadius: CGFloat {
        switch stage {
        case 0: 12
        case 1: 4
        default: 0
        }
    }

    private var scale: CGFloat {
        switch stage {
        case 0: 0.94
        case 1: 0.975
        default: 1
        }
    }

    private var noteOpacity: Double {
        switch stage {
        case 0: 0.4
        case 1: 0.8
        default: 1
        }
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
