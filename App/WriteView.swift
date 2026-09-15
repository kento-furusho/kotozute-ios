import SwiftUI

/// ことづてを書く／書き直す。1枚 = 付箋1枚。
///
/// 編集は書くサイクルのものだけ。オープン済みは確定扱いで、サーバーが 409 で弾く。
struct WriteView: View {
    let title: String
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var body_: String
    @State private var color: String
    @FocusState private var isFocused: Bool

    /// - Parameters:
    ///   - initialBody: 空なら新規、入っていれば書き直し。
    ///   - initialColor: 書き直しのときは元の色。新規は既定の1色目。
    init(
        title: String = "ことづてを書く",
        initialBody: String = "",
        initialColor: String? = nil,
        onSave: @escaping (String, String) -> Void
    ) {
        self.title = title
        self.onSave = onSave
        _body_ = State(initialValue: initialBody)
        _color = State(initialValue: initialColor ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                .frame(height: 220)
                // 選んだ色をそのまま下地にする。書いている紙が仕上がりと同じになる。
                .background((Theme.stickyPaper(hex: color) ?? Theme.stickyPaper(at: 0)).gradient)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                .padding(20)

                ColorChooser(selection: $color, autoColor: Theme.stickyPaper(at: 0).base)
                    .padding(.horizontal, 20)

                Spacer()
            }
            .background(Theme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("やめる") { dismiss() }
                        .foregroundStyle(Theme.inkSoft)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("しまう") {
                        onSave(body_, color)
                        dismiss()
                    }
                    .font(Theme.font(17, weight: .bold))
                    .foregroundStyle(canSave ? Theme.accent : Theme.inkSoft)
                    .disabled(!canSave)
                }
            }
            .onAppear { isFocused = true }
        }
    }

    private var canSave: Bool {
        !body_.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
