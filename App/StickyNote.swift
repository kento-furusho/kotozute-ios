import KotozuteAPI
import SwiftUI

/// ことづて1つの見た目。モノは付箋、呼称は「ことづて」。
///
/// 平坦な矩形にならないよう、docs/design/ の作り込み案から4つの要素を写している:
///   - 上が明るく下が濃いグラデーション（紙が光を受けている感じ）
///   - ほぼ直角の角。付箋は角丸ではない
///   - 下に落ちる柔らかい影（浮いて見せる）
///   - 上端の内側に白い線（紙の厚みの縁）
/// さらにマスキングテープで「貼ってある」ことを示す。
struct StickyNote: View {
    let kotozute: Kotozute
    let paper: Theme.StickyPaper
    /// 並べたときに単調にならないよう傾ける。
    let tilt: Double
    /// テープの傾き。付箋と別にずらすと、貼った手つきに見える。
    var tapeTilt: Double = -1.5
    /// 1枚ずつ読む画面用。文字も紙も大きくする。
    var isLarge: Bool = false

    var body: some View {
        // 本文は上、日付は下端。デザイン案の space-between と同じ振り分け。
        // 余白が下にまとまらず、紙全体を使っているように見える。
        VStack(alignment: .leading, spacing: 10) {
            Text(kotozute.body)
                .font(Theme.font(isLarge ? 20 : 16))
                .foregroundStyle(Theme.ink)
                .lineSpacing(isLarge ? 8 : 5)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            Text(Self.dayFormatter.string(from: kotozute.createdAt))
                .font(Theme.font(isLarge ? 13 : 12))
                .foregroundStyle(Theme.ink.opacity(0.42))
        }
        .padding(.horizontal, isLarge ? 26 : 16)
        .padding(.top, isLarge ? 32 : 20)
        .padding(.bottom, isLarge ? 22 : 14)
        // 正方形に近い形が付箋らしさの大半を作る。ただし本文が長いときは伸びてよい
        // （切り詰めると読めなくなる。ことづては読ませるものなので隠さない）。
        .frame(maxWidth: .infinity, minHeight: isLarge ? 260 : 150, alignment: .topLeading)
        .background(paper.gradient)
        // 紙の厚みに見える縁。クリップの内側に入れる。
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.5))
                .frame(height: 1)
        }
        // 付箋の角はほぼ直角。角丸にするとカードに見えてしまう。
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .shadow(color: Color(hex: 0x3A322C).opacity(0.28), radius: 9, x: 0, y: 7)
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

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        // 端末が和暦でも表示がぶれないようにする。
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "M月d日"
        return formatter
    }()
}

/// 付箋を2列に並べる。デザイン案の「板に貼ってある」並びに寄せる。
/// 傾きは位置から決めて、再描画でぶれないようにする。
struct StickyNoteList: View {
    let items: [Kotozute]
    /// 色の巡回開始位置。自分と相手で色が揃いすぎないようにずらす。
    var colorOffset: Int = 0
    /// タップで開くとき（書き直し）。nil ならタップに反応しない。
    var onTap: ((Kotozute) -> Void)?

    /// 傾きの並び。同じ角度が続かないよう、順に振り分ける。
    private static let tilts: [Double] = [-2.2, 1.6, -1.1, 2.1, -1.7, 1.2]
    private static let tapeTilts: [Double] = [-1.5, 2.0, -2.4, 1.4, -1.0, 2.6]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
            spacing: 24
        ) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let note = StickyNote(
                    kotozute: item,
                    paper: Theme.stickyPaper(at: index + colorOffset),
                    tilt: Self.tilts[index % Self.tilts.count],
                    tapeTilt: Self.tapeTilts[index % Self.tapeTilts.count]
                )
                if let onTap {
                    Button { onTap(item) } label: { note }
                        .buttonStyle(.plain)
                } else {
                    note
                }
            }
        }
        // 傾いた角とテープが切れないよう、まわりに余白を持たせる。
        .padding(.horizontal, 4)
        .padding(.top, 10)
    }
}
