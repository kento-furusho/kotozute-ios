import SwiftUI

/// オンボーディングの「最初の1枚」。招待より前に書く。
///
/// ことづては書いた人の下に保存されるので、ペアが無くても書ける。
/// 相手を誘う前に「書く」を一度体験してもらうための画面。
struct FirstKotozuteView: View {
    @Bindable var store: KotozuteStore
    let onDone: () -> Void

    @State private var body_ = ""
    @State private var isSaving = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text("最初のことづて")
                .font(Theme.font(26, weight: .bold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 40)

            Text("さいきん、いいなと思ったこと。\nひとことでいい。")
                .font(Theme.font(15))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 10)

            ZStack(alignment: .topLeading) {
                if body_.isEmpty {
                    Text("いいな、と思ったこと")
                        .font(Theme.font(16))
                        .foregroundStyle(Theme.ink.opacity(0.3))
                        .padding(.top, 20)
                        .padding(.leading, 20)
                }
                TextEditor(text: $body_)
                    .font(Theme.font(16))
                    .foregroundStyle(Theme.ink)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .focused($isFocused)
            }
            .frame(height: 200)
            .background(Theme.stickyPaper(at: 0).gradient)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .shadow(color: Theme.ink.opacity(0.24), radius: 9, y: 7)
            .padding(.top, 28)

            Spacer()

            Button {
                Task {
                    isSaving = true
                    await store.write(body_)
                    isSaving = false
                    onDone()
                }
            } label: {
                Group {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("しまう").font(Theme.font(17, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? Theme.accent : Theme.inkSoft.opacity(0.4))
                .clipShape(Capsule())
            }
            .disabled(!canSave || isSaving)

            Button("あとで", action: onDone)
                .font(Theme.font(14))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 16)

            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .onAppear { isFocused = true }
    }

    private var canSave: Bool {
        !body_.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
