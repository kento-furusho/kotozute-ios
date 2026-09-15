import SwiftUI

/// 付箋の色を選ぶ。既定の色を並べて、右端に自由に選べる口を置く。
///
/// 色は書いたことづてに保存され、相手の画面でもその色で出る。
/// 「誰が書いたか」ではなく「どのことづてか」に付くので、
/// 同じ人の付箋でも1枚ごとに違ってよい。
struct ColorChooser: View {
    @Binding var selection: String

    /// ColorPicker は Color でしか扱えないので、選択中の16進数と行き来させる。
    private var custom: Binding<Color> {
        Binding(
            get: { Theme.stickyPaper(hex: selection)?.base ?? Theme.stickyPaper(at: 0).base },
            set: { newValue in
                if let hex = newValue.hexString { selection = hex }
            }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Theme.stickyBaseHexes, id: \.self) { hex in
                Button {
                    selection = hex
                } label: {
                    swatch(
                        color: Theme.stickyPaper(hex: hex)?.base ?? .clear,
                        isSelected: hex.caseInsensitiveCompare(selection) == .orderedSame
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            // 自由に選ぶ口。既定の色に無い色を使いたい人向け。
            // ラベルは出さない（並んだ丸の延長に見せたいので）。
            ColorPicker("色を選ぶ", selection: custom, supportsOpacity: false)
                .labelsHidden()
        }
    }

    private func swatch(color: Color, isSelected: Bool) -> some View {
        Circle()
            .fill(color)
            .frame(width: 28, height: 28)
            .overlay(Circle().stroke(Theme.ink.opacity(0.12), lineWidth: 1))
            .overlay(
                // 選択中は外側に輪を描く。丸自体を大きくすると並びが揺れる。
                Circle()
                    .stroke(Theme.ink.opacity(isSelected ? 0.55 : 0), lineWidth: 2)
                    .padding(-4)
            )
            .accessibilityLabel(isSelected ? "選択中の色" : "色")
    }
}
