import SwiftUI

/// いちばん最初の画面。ここは「なぜ良いか」だけを言う。
/// 「どう動くか」はサインイン後のコンセプト2枚（ConceptView）が担当し、同じ説明を2度しない。
struct WelcomeView: View {
    let onStart: () -> Void
    let onSignIn: () -> Void

    var body: some View {
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

            stickyPreview
                .padding(.top, 34)

            Text("ふたりの壁に、静かにたまっていく。")
                .font(Theme.font(15))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 34)
                .appearsInOrder(5)

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

    /// 見本のことづて。ここは飾りではなく「何を書けばいいのか」を見せる場所。
    /// 色板だけにすると、書きはじめる前のいちばん大きな不安が残る。
    private var stickyPreview: some View {
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
}
