import SwiftUI

/// 招待コードを入れるシート。招待された人の入口。
///
/// 以前は招待する側の画面（InviteView）に「招待をもらっている」として置いていた。
/// 招待する人にとっては関係の無いボタンで、送るボタンの邪魔をしていた。
/// いまは次の2か所から開く:
/// - 最初の「はじめる」の画面（登録より前。招待された人はここから入る）
/// - 設定（コードを入れずに登録してしまった人のため。ペア未成立のときだけ）
///
/// 入れたコードは InviteRouter に渡す。あとは招待リンクから来たときと同じ流れ
/// （「◯◯からの招待」→ 登録 → ペアを組む）になる。
struct InviteCodeEntryView: View {
    let onSubmit: (String) -> Void
    @State private var code = ""
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private var trimmed: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("招待コード")
                .font(Theme.font(24, weight: .bold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 36)

            Text("招待した方から届いたメッセージにある\nコードを入れてください。")
                .font(Theme.font(15))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 10)

            TextField("招待コード", text: $code)
                .font(Theme.font(16))
                // コードは英数字とハイフンだけ。日本語入力のままだと変換に化ける。
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit(submit)
                .focused($isFocused)
                .padding(14)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                .padding(.top, 28)

            Button(action: submit) {
                Text("すすむ")
                    .font(Theme.font(17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(trimmed.isEmpty ? Theme.inkSoft.opacity(0.4) : Theme.accent)
                    .clipShape(Capsule())
            }
            .disabled(trimmed.isEmpty)
            .padding(.top, 20)

            Button("閉じる") { dismiss() }
                .font(Theme.font(15))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 16)

            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .onAppear { isFocused = true }
    }

    private func submit() {
        guard !trimmed.isEmpty else { return }
        // 先に閉じる。閉じてから渡さないと、シートの下で画面が切り替わり、
        // 切り替わった先の上にシートが残って見えることがある。
        let value = trimmed
        dismiss()
        onSubmit(value)
    }
}
