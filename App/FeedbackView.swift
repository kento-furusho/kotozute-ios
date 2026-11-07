import KotozuteAPI
import SwiftUI

/// ご意見・ご要望。アプリの中から送る。
///
/// 「問題を報告する」（不適切な内容の報告、メールが開く）とは分けている。
/// 意見を伝えたいだけの人には「報告」は押しにくい。
/// アプリ内で送ると、送った人（userID）と版がサーバーで自動的に付く。
struct FeedbackView: View {
    @Bindable var store: KotozuteStore

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var isSent = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if isSent {
                    sent
                } else {
                    form
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("ご意見・ご要望")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isSent {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("やめる") { dismiss() }
                            .foregroundStyle(Theme.inkSoft)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isSending ? "送信中…" : "送信する") { send() }
                            .font(Theme.font(17, weight: .bold))
                            .foregroundStyle(canSend ? Theme.accent : Theme.inkSoft)
                            .disabled(!canSend || isSending)
                    }
                }
            }
        }
        // 書きかけをスワイプで閉じて失わないように。
        .interactiveDismissDisabled(!text.isEmpty && !isSent)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("使ってみての感想や、こうなったらいいなと思うことをお聞かせください。")
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.ink)

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("感想や、あったらいいなと思う機能など")
                            .font(Theme.font(16))
                            .foregroundStyle(Theme.ink.opacity(0.3))
                            .padding(.top, 20)
                            .padding(.leading, 18)
                    }
                    TextEditor(text: $text)
                        .font(Theme.font(16))
                        .foregroundStyle(Theme.ink)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .focused($isFocused)
                }
                .frame(height: 220)
                .background(.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                .padding(.top, 16)

                HStack(alignment: .top) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(Theme.font(13))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer()
                    // 上限に近づいたときだけ数を出す。ふだんは気にさせない。
                    if text.count > FeedbackRequest.maxLength - 200 {
                        Text("\(text.count) / \(FeedbackRequest.maxLength)")
                            .font(Theme.font(12))
                            .foregroundStyle(isTooLong ? Theme.accent : Theme.inkSoft)
                            .monospacedDigit()
                    }
                }
                .padding(.top, 8)

                Text("返信が必要なときは、設定の「サポート」からメールでご連絡ください。")
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 16)
            }
            .padding(20)
        }
        .onAppear { isFocused = true }
    }

    private var sent: some View {
        VStack(spacing: 0) {
            Text("ありがとうございます")
                .font(Theme.font(20, weight: .bold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 48)

            Text("ご意見を受け付けました。今後の改善に使わせていただきます。")
                .font(Theme.font(15))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            Button {
                dismiss()
            } label: {
                Text("閉じる")
                    .font(Theme.font(15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            .padding(.top, 32)
        }
        .padding(.horizontal, 24)
    }

    private var isTooLong: Bool { text.count > FeedbackRequest.maxLength }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTooLong
    }

    private func send() {
        Task {
            isSending = true
            errorMessage = nil
            let failure = await store.sendFeedback(text)
            isSending = false
            if let failure {
                errorMessage = failure
            } else {
                isFocused = false
                withAnimation(.easeInOut(duration: 0.18)) { isSent = true }
            }
        }
    }
}
