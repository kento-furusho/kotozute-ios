import SwiftUI

/// 書くときのヒント。デザイン案どおり「畳んで置く」。
///
/// 常に大きく出すと宿題に見えてしまう。詰まった人だけが開ける逃げ道にする。
struct WritingHint: View {
    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("書くことに迷ったら")
                        .font(Theme.font(13))
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Theme.inkSoft)
            }
            .buttonStyle(.plain)

            if isOpen {
                // 開いて1行だと、畳んである意味がない。
                // 種類の違う切り口を並べて、どれかに引っかかるようにする。
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Self.hints, id: \.self) { hint in
                        Text("・\(hint)")
                            .font(Theme.font(14))
                            .foregroundStyle(Theme.ink.opacity(0.75))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.leading, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 大きい出来事でなくてよい、と伝わる並びにする。
    /// 「感謝」だけに寄せると、特別な日しか書けなくなる。
    private static let hints = [
        "最近ありがとうと思ったこと",
        "助かった、と思った瞬間",
        "言いそびれたまま流れたこと",
        "当たり前になっていること",
    ]
}
