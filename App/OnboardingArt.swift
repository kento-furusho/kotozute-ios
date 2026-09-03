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

/// 気配の表示に使う、ぼかした付箋の束。
///
/// **中身は持たない。** サーバーはロック中に相手の本文を返さないし、枚数も返さない。
/// だから本文らしきものを描かず、線の帯だけを置いてぼかす。
/// 偽の文章を敷いてぼかすと、解像度を上げれば読めてしまう見た目になり、
/// 「本当は持っているのに隠している」という誤解を招く。
///
/// **重ねるのは、数を数えさせないため。** 並べて置くと枚数を読み取ろうとするし、
/// 実際の枚数と食い違えば嘘になる。重ねれば後ろは縁しか見えず、
/// 「何かある」だけが伝わる。枚数は点数表になるので出さない
/// （プライバシーポリシーにも「書いた枚数など、本文以外の情報も
/// 相手には表示されません」と書いてある）。
struct BlurredNotes: View {
    var body: some View {
        GeometryReader { geometry in
            // 壁の2列組みと同じ幅にして、1枚ぶんの場所に束が置いてあるように見せる。
            let side = (geometry.size.width - 16) / 2
            ZStack(alignment: .topLeading) {
                // ずらし幅はぼかしの半径より大きくとる。小さいと滲みに紛れて、
                // 重なった紙ではなく色の滲みに見える。
                paper(at: 4, tilt: 4.2, bars: [])
                    .frame(width: side, height: 150)
                    .offset(x: 30, y: -16)
                paper(at: 3, tilt: -3.6, bars: [])
                    .frame(width: side, height: 150)
                    .offset(x: 15, y: -8)
                paper(at: 2, tilt: -1.2, bars: [0.78, 0.86, 0.45])
                    .frame(width: side, height: 150)
            }
            .blur(radius: 6)
        }
        // ぼかすと縁が滲むので、束のぶんだけ余白を足して紙の形を保つ。
        .frame(height: 172)
        .padding(.top, 10)
        .accessibilityElement()
        .accessibilityLabel("相手のことづて。まだ読めない")
    }

    private func paper(at index: Int, tilt: Double, bars: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, width in
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
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .stickyPaper(Theme.stickyPaper(at: index), tilt: tilt)
    }
}
