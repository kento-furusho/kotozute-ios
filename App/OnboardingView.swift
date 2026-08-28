import SwiftUI

/// 最初に見る画面。登録より前に、何のアプリで何がいいのかを見せきる。
///
/// デザイン案（初回導線A）は ①はじめる → ②登録 → ③コンセプト の順で、
/// 説明が登録のあとにあった。メールとパスワードを入れる前に、
/// これが何なのか分からないまま進むことになる。順序を入れ替えている。
///
/// ここに登録の手順は混ぜない。説明だけを最後まで見せて、
/// 「はじめる」で初めて登録へ渡す。
struct OnboardingView: View {
    let onStart: () -> Void
    let onSignIn: () -> Void
    /// 確認用に途中のページから開けるようにしている。通常は 0。
    var startPage = 0

    @State private var page = 0

    private static let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            skip

            TabView(selection: $page) {
                intro.tag(0)
                concept(
                    art: { WeekStrip() },
                    title: "週に一度のオープン",
                    body: "書いたことづては、その日まで貼ったまま。\n決まった曜日に、その週ぶんがまとまる。"
                ).tag(1)
                concept(
                    art: { ExchangeDiagram() },
                    title: "ことづての交換",
                    body: "じぶんが書くと、あいてのことづても見られる。\n書かない週は、静かに待つだけでいい。"
                ).tag(2)
                concept(
                    art: { WallPreview() },
                    title: "ふたりの壁",
                    body: "オープンした分は、あとから何度でも読み返せる。\n週ごとにさかのぼれる。"
                ).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))

            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .onAppear { page = startPage }
    }

    private var isLastPage: Bool { page == Self.pageCount - 1 }

    /// 説明を飛ばして登録へ。急いでいる人を4枚めくらせない。
    private var skip: some View {
        HStack {
            Spacer()
            Button("スキップ", action: onStart)
                .font(Theme.font(15))
                .foregroundStyle(Theme.inkSoft)
                .opacity(isLastPage ? 0 : 1)
                .disabled(isLastPage)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.2), value: isLastPage)
    }

    /// 1枚目。ここは仕組みを言わず、何が起きるかだけを見せる。
    /// 見本のことづては飾りではなく「何を書けばいいのか」を伝える役目を持つ。
    private var intro: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("ことづて")
                .font(Theme.font(38, weight: .bold))
                .foregroundStyle(Theme.ink)
                .appearsInOrder(0)

            Text("言いそこねた「ありがとう」を、\nことづてにして貼っておく。")
                .font(Theme.font(16))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.top, 14)
                .appearsInOrder(1)

            samples
                .padding(.top, 34)

            Text("ふたりの壁に、静かにたまっていく。")
                .font(Theme.font(15))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 34)
                .appearsInOrder(5)

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var samples: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                SampleNote(text: "おかえりの声、\n元気だった", paperIndex: 0, tilt: -3)
                    .appearsInOrder(2)
                SampleNote(text: "プリン、\nゆずってくれた", paperIndex: 2, tilt: 4)
                    .appearsInOrder(3)
            }
            SampleNote(text: "寝る前の「おつかれ」", paperIndex: 1, tilt: -2, width: 132, minHeight: 76)
                .appearsInOrder(4)
        }
    }

    /// 2枚目以降。図が説明の大半を引き受け、文章は最小にする。
    private func concept(
        @ViewBuilder art: () -> some View,
        title: String,
        body: String
    ) -> some View {
        VStack(spacing: 0) {
            Spacer()

            art()
                .frame(height: 190)

            Text(title)
                .font(Theme.font(28, weight: .bold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 40)

            Text(body)
                .font(Theme.font(16))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.top, 14)

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var actions: some View {
        VStack(spacing: 0) {
            Button {
                if isLastPage {
                    onStart()
                } else {
                    withAnimation { page += 1 }
                }
            } label: {
                Text(isLastPage ? "はじめる" : "つぎへ")
                    .font(Theme.font(17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }

            // 戻ってきた人が4枚めくらされないよう、最初から出しておく。
            Button("アカウントを持っている", action: onSignIn)
                .font(Theme.font(15))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 16)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }
}
