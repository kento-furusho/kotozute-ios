import SwiftUI

/// 登録直後の3枚（ニックネーム → 最初のことづて → 招待）の、いまどこかを示す点。
///
/// 先が見えないと、画面が続くたびに「まだあるのか」と感じる。
/// 3枚だと分かっていれば、1枚ずつの重さが軽くなる。
struct OnboardingSteps: View {
    /// 0 から数える。
    let current: Int
    var total = 3

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Theme.accent : Theme.line)
                    .frame(width: index == current ? 18 : 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(total)つのうち\(current + 1)つ目")
    }
}
