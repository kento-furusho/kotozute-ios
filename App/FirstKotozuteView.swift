import SwiftUI

/// オンボーディングの「最初の1枚」。招待より前に書く。登録直後の3枚の2枚目。
///
/// ことづては書いた人の下に保存されるので、ペアが無くても書ける。
/// 相手を誘う前に「書く」を一度体験してもらうための画面。
///
/// **キーボードを閉じられるようにする。** 以前は開いた瞬間にキーボードが出て、
/// 閉じる手段が無く、「貼っておく」「あとで」がキーボードの下に隠れて押せなくなった。
/// 中身をスクロールできるようにし、キーボードの上に「閉じる」を置き、
/// 付箋の外を触っても閉じるようにした。
struct FirstKotozuteView: View {
    @Bindable var store: KotozuteStore
    let onDone: () -> Void

    @State private var body_ = ""
    /// ふだんの「書く」と同じく、1枚ごとに色を選べる。既定は1色目。
    @State private var color = Theme.stickyHex(at: 0)
    @State private var isSaving = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                OnboardingSteps(current: 1)
                    .padding(.top, 20)

                Text("最初のことづて")
                    .font(Theme.font(26, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 32)

                Text("つながった相手が最初に見るのは、このことづてです。")
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
                // 選んだ色をそのまま下地にする。書いている紙が仕上がりと同じになる。
                .background((Theme.stickyPaper(hex: color) ?? Theme.stickyPaper(at: 0)).gradient)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .shadow(color: Theme.ink.opacity(0.24), radius: 9, y: 7)
                .padding(.top, 28)

                ColorChooser(selection: $color)
                    .padding(.top, 18)

                WritingHint()
                    .padding(.top, 14)

                Button(action: save) {
                    Group {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("貼っておく").font(Theme.font(17, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSave ? Theme.accent : Theme.inkSoft.opacity(0.4))
                    .clipShape(Capsule())
                }
                .disabled(!canSave || isSaving)
                .padding(.top, 32)

                Button("あとで", action: onDone)
                    .font(Theme.font(14))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 28)
        }
        // 下へ払うとキーボードが下がる。
        .scrollDismissesKeyboard(.interactively)
        // 付箋の外を触ったら閉じる。
        .contentShape(Rectangle())
        .onTapGesture { isFocused = false }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        // キーボードのすぐ上に「閉じる」。キーボード用のツールバー（placement: .keyboard）は
        // ナビゲーションバーを隠した画面や、出た瞬間にフォーカスする画面で出ないことがあり、
        // 実際にこの画面で出なかった。フォーカス中だけ下端に自前の帯を置く
        // （下端の safe area はキーボードの上端まで上がる）。
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isFocused {
                HStack {
                    Spacer()
                    Button("閉じる") { isFocused = false }
                        .font(Theme.font(16, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .background(Theme.background)
                .overlay(alignment: .top) { Divider() }
            }
        }
        .onAppear { isFocused = true }
    }

    private var canSave: Bool {
        !body_.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        Task {
            isFocused = false
            isSaving = true
            await store.write(body_, color: color)
            isSaving = false
            onDone()
        }
    }
}
