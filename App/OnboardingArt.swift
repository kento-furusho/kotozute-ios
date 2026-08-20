import SwiftUI

/// オンボーディングで見せる図。
///
/// デザイン案（docs/design/ の初回導線A ③-1・③-2）では、ここは抽象的な図形ではなく
/// 具体物になっている。とくに文面入りの付箋は飾りではなく、
/// **何を書けばいいのか**を見せる役目を持っている。
/// 色板だけにすると、その役目が丸ごと落ちる。

/// 見本のことづて。日付は出さない（まだ誰も書いていないので、嘘の日付になる）。
struct SampleNote: View {
    let text: String
    let paperIndex: Int
    let tilt: Double
    var width: CGFloat = 104
    /// 付箋は正方形に近いほうがそれらしい。本文が短くても高さを保つ。
    var minHeight: CGFloat = 104

    var body: some View {
        Text(text)
            .font(Theme.font(13))
            .foregroundStyle(Theme.ink)
            .lineSpacing(4)
            .multilineTextAlignment(.leading)
            .frame(width: width, alignment: .topLeading)
            .padding(.horizontal, 14)
            .padding(.top, 22)
            .padding(.bottom, 14)
            // 高さは余白を含めた紙全体にかける。本文が1行でも潰れない。
            .frame(minHeight: minHeight, alignment: .topLeading)
            .stickyPaper(Theme.stickyPaper(at: paperIndex), tilt: tilt)
    }
}

/// 1週間の帯。オープンの日だけが色付きで、そこまで書きためることを示す。
///
/// 曜日は設定で変えられるが、ここはまだ設定前なので、案内としての例を出す。
struct WeekStrip: View {
    /// 0=日〜6=土。案内なので既定は金曜。
    var openDayOfWeek = 5
    /// 何日目まで「書いた」印を出すか。溜まっていく様子を見せるため。
    var writtenThrough = 3

    private let labels = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { day in
                VStack(spacing: 6) {
                    // 書いた日には小さな付箋を1枚。無い日は場所だけ空けて高さを揃える。
                    Group {
                        if day <= writtenThrough, day != openDayOfWeek {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.stickyPaper(at: day).gradient)
                                .frame(width: 22, height: 22)
                                .rotationEffect(.degrees(day.isMultiple(of: 2) ? -6 : 5))
                        } else {
                            Color.clear.frame(width: 22, height: 22)
                        }
                    }

                    Text(labels[day])
                        .font(Theme.font(12, weight: day == openDayOfWeek ? .bold : .regular))
                        .foregroundStyle(day == openDayOfWeek ? .white : Theme.inkSoft)
                        .frame(width: 34, height: 34)
                        .background {
                            if day == openDayOfWeek {
                                Circle().fill(Theme.accent)
                            }
                        }
                }
            }
        }
    }
}

/// 交換の図。じぶんが書くと、あいての分も見られる、という一方向ではない関係を示す。
struct ExchangeDiagram: View {
    var body: some View {
        HStack(spacing: 12) {
            column(label: "じぶん", paperIndex: 0, tilt: -4)

            VStack(spacing: 6) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("こうかん")
                    .font(Theme.font(11, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
            }

            column(label: "あいて", paperIndex: 2, tilt: 4)
        }
    }

    private func column(label: String, paperIndex: Int, tilt: Double) -> some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Theme.stickyPaper(at: paperIndex).gradient)
                .frame(width: 84, height: 84)
                .overlay(alignment: .topLeading) { writingLines.padding(14) }
                .shadow(color: Theme.ink.opacity(0.22), radius: 6, y: 4)
                .rotationEffect(.degrees(tilt))

            Text(label)
                .font(Theme.font(12, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    /// 文字が書いてある雰囲気だけを出す線。実際の文面は Welcome で見せている。
    private var writingLines: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(0..<3, id: \.self) { line in
                Capsule()
                    .fill(Theme.ink.opacity(0.18))
                    .frame(width: line == 2 ? 30 : 56, height: 3)
            }
        }
    }
}

/// 少し遅れて現れる。順に貼られていくように見せるためのもの。
struct AppearsInOrder: ViewModifier {
    let index: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)
                    .delay(0.12 * Double(index))) {
                    shown = true
                }
            }
    }
}

extension View {
    func appearsInOrder(_ index: Int) -> some View {
        modifier(AppearsInOrder(index: index))
    }
}
