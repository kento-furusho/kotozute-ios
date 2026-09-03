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
    /// 紙の一辺。付箋は正方形。
    ///
    /// 余白を含めた紙全体にかける。本文側に幅を与えて外から高さだけ足す形だと、
    /// 文の長さで縦横比が変わってしまう。
    var side: CGFloat = 132

    var body: some View {
        Text(text)
            // 改行は指定しない。端末の幅や文字サイズの設定で崩れるため、
            // 紙のほうを画面に合わせて伸縮させ、折り返しは任せる。
            .font(Theme.font(13))
            .foregroundStyle(Theme.ink)
            .lineSpacing(4)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 14)
            .padding(.top, 22)
            .padding(.bottom, 14)
            .frame(width: side, height: side, alignment: .topLeading)
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

/// 気配の表示に使う、ぼかした付箋。
///
/// **中身は持たない。** サーバーはロック中に相手の本文を返さないし、枚数も返さない。
/// だから本文らしきものを描かず、線の帯だけを置いてぼかす。
/// 偽の文章を敷いてぼかすと、解像度を上げれば読めてしまう見た目になり、
/// 「本当は持っているのに隠している」という誤解を招く。
///
/// 枚数は**常に2枚**で、相手が何枚書いたかとは関係がない。
/// 枚数を映すと「存在のみ伝える」という決めごとが崩れる。
struct BlurredNotes: View {
    var body: some View {
        HStack(spacing: 16) {
            note(paper: Theme.stickyPaper(at: 2), tilt: -2.2, widths: [0.78, 0.86, 0.45])
            note(paper: Theme.stickyPaper(at: 3), tilt: 1.6, widths: [0.86, 0.62])
        }
        .blur(radius: 7)
        // ぼかすと縁が滲んで見えるので、少しだけ内側に置いて紙の形を保つ。
        .padding(.vertical, 4)
        .accessibilityElement()
        .accessibilityLabel("相手のことづて。まだ読めない")
    }

    private func note(paper: Theme.StickyPaper, tilt: Double, widths: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(widths.enumerated()), id: \.offset) { _, width in
                GeometryReader { geometry in
                    Capsule()
                        .fill(Theme.ink.opacity(0.55))
                        .frame(width: geometry.size.width * width, height: 9)
                }
                .frame(height: 9)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 26)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .stickyPaper(paper, tilt: tilt)
    }
}
