import SwiftUI

/// コンセプト2枚。ここは「どう動くか」だけを言う。
/// 惹きつけ（なぜ良いか）は WelcomeView が済ませているので繰り返さない。
struct ConceptView: View {
    let onDone: () -> Void
    /// 確認用に途中のページから開けるようにしている。通常は 0。
    var startPage = 0

    @State private var page = 0

    private struct Page {
        let title: String
        let body: String
    }

    private let pages = [
        Page(
            title: "週に一度のオープン",
            body: "書いたことづては、その日まで貼ったまま。\n決まった曜日に、その週ぶんがまとまる。"
        ),
        Page(
            title: "ことづての交換",
            body: "じぶんが書くと、あいてのことづても見られる。\n書かない週は、静かに待つだけでいい。"
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 0) {
                        Spacer()
                        illustration(for: index)
                        Text(item.title)
                            .font(Theme.font(28, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .padding(.top, 40)
                        Text(item.body)
                            .font(Theme.font(16))
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.top, 14)
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onDone()
                }
            } label: {
                Text(page < pages.count - 1 ? "つぎへ" : "はじめる")
                    .font(Theme.font(17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .onAppear { page = startPage }
    }

    @ViewBuilder
    private func illustration(for index: Int) -> some View {
        // デザイン案（初回導線A ③-1・③-2）に合わせて、抽象図形ではなく
        // 「1週間の帯」と「交換の図」を出す。どちらも仕組みの説明を絵で肩代わりする。
        if index == 0 {
            WeekStrip()
                .frame(height: 150)
        } else {
            ExchangeDiagram()
                .frame(height: 150)
        }
    }
}
