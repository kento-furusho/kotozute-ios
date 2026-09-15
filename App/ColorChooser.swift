import SwiftUI

/// 付箋の色を選ぶ。「おまかせ」＋既定の色＋自由選択。
///
/// 色は書いたことづてに保存され、相手の画面でもその色で出る。
/// 「誰が書いたか」ではなく「どのことづてか」に付くので、
/// 同じ人の付箋でも1枚ごとに違ってよい。
///
/// `selection` が空文字なら「おまかせ」。色を持たせず、画面が並び順から決める。
/// これまでの見た目（6色が巡回する壁）はこの状態のもの。
struct ColorChooser: View {
    @Binding var selection: String
    /// おまかせを選んでいるときに、その付箋が実際になる色。
    /// 並ぶ位置が決まっているので本物と同じ色を出せる。
    let autoColor: Color

    /// 既定の色。Theme の付箋色をそのまま使う。
    private static let presets: [String] = [
        "FFDC72", "B9E6D0", "FFC0AB", "C4DAF6", "DCC8F8", "F7B9CE",
    ]

    private var isAuto: Bool { selection.isEmpty }

    /// おまかせの丸に使う色。最後に先頭をもう一度足して、輪の継ぎ目をなくす。
    /// 式のまま書くと型チェックが重くなるので、ここで組んでおく。
    private static let wheelColors: [Color] = {
        var colors: [Color] = presets.map { Theme.stickyPaper(hex: $0)?.base ?? .clear }
        if let first = colors.first {
            colors.append(first)
        }
        return colors
    }()

    /// ColorPicker は Color でしか扱えないので、選択中の16進数と行き来させる。
    private var custom: Binding<Color> {
        Binding(
            get: { Theme.stickyPaper(hex: selection)?.base ?? autoColor },
            set: { newValue in
                if let hex = newValue.hexString { selection = hex }
            }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: roll) { autoSwatch }
                .buttonStyle(.plain)

            ForEach(Self.presets, id: \.self) { hex in
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

    /// 押すたびに既定の色から1つ引く。いまと同じ色は引かないので、必ず変わる。
    ///
    /// 押す前は「おまかせ」（色を持たず、並び順で決まる）。一度押すと、
    /// 引いた色がそのことづての色になる。書く画面を開き直すとおまかせに戻る。
    private func roll() {
        let candidates = Self.presets.filter { $0.caseInsensitiveCompare(selection) != .orderedSame }
        guard let picked = candidates.randomElement() else { return }
        selection = picked
    }

    /// おまかせ。既定の色を回した輪にして、「どれか1色ではない」ことを見せる。
    private var autoSwatch: some View {
        Circle()
            .fill(AngularGradient(colors: Self.wheelColors, center: .center))
            .frame(width: 28, height: 28)
            .overlay(Circle().stroke(Theme.ink.opacity(0.12), lineWidth: 1))
            .overlay(
                Circle()
                    .stroke(Theme.ink.opacity(isAuto ? 0.55 : 0), lineWidth: 2)
                    .padding(-4)
            )
            .accessibilityLabel("色をランダムに選ぶ")
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
