import SwiftUI

/// コンセプト2枚。ここは「どう動くか」だけを言う。
/// 惹きつけ（なぜ良いか）は WelcomeView が済ませているので繰り返さない。
struct ConceptView: View {
    let onDone: () -> Void

    @State private var page = 0

    private struct Page {
        let title: String
        let body: String
    }

    private let pages = [
        Page(
            title: "書きためる",
            body: "思ったときに書く。\n頻度の縛りはない。"
        ),
        Page(
            title: "週に一度、オープン",
            body: "決まった日に、ふたりのことづてがまとまる。\nじぶんが書いていると、相手の分も見られる。"
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
    }

    @ViewBuilder
    private func illustration(for index: Int) -> some View {
        if index == 0 {
            // 溜まっていく様子。
            VStack(spacing: -46) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.stickyColor(at: i))
                        .frame(width: 150, height: 92)
                        .shadow(color: .black.opacity(0.08), radius: 5, y: 3)
                        .rotationEffect(.degrees(i.isMultiple(of: 2) ? -3 : 3))
                }
            }
            .frame(height: 150)
        } else {
            // ふたりぶんが並ぶ様子。
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.stickyColor(at: 2))
                    .frame(width: 116, height: 132)
                    .rotationEffect(.degrees(-4))
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.stickyColor(at: 0))
                    .frame(width: 116, height: 132)
                    .rotationEffect(.degrees(4))
            }
            .shadow(color: .black.opacity(0.08), radius: 5, y: 3)
            .frame(height: 150)
        }
    }
}
