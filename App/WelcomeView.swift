import SwiftUI

/// いちばん最初の画面。ここは「なぜ良いか」だけを言う。
/// 「どう動くか」はサインイン後のコンセプト2枚（ConceptView）が担当し、同じ説明を2度しない。
struct WelcomeView: View {
    let onStart: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            stickyPreview

            Text("ことづて")
                .font(Theme.font(38, weight: .bold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 40)

            Text("いいな、と思ったことを書きためて、\n週に一度ふたりで読む。")
                .font(Theme.font(16))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.top, 14)

            Spacer()

            Button(action: onStart) {
                Text("はじめる")
                    .font(Theme.font(17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }

            Button("アカウントを持っている", action: onSignIn)
                .font(Theme.font(15))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 18)

            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }

    /// 何のアプリかを一目で伝えるための飾り。文言では説明しない。
    private var stickyPreview: some View {
        ZStack {
            note(Theme.stickyColor(at: 2), rotation: -8, offset: CGSize(width: -54, height: 6))
            note(Theme.stickyColor(at: 1), rotation: 6, offset: CGSize(width: 52, height: 12))
            note(Theme.stickyColor(at: 0), rotation: -1, offset: .zero)
        }
        .frame(height: 132)
    }

    private func note(_ color: Color, rotation: Double, offset: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(color)
            .frame(width: 116, height: 116)
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
    }
}
