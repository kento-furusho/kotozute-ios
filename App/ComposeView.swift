import KotozuteAPI
import SwiftUI

/// 「書く」タブ。書く場所と、いま書きためている分を同じ画面に置く。
///
/// 「見る」は相手のことづてを読む場所、「書く」は自分の分を扱う場所、という分け方。
struct ComposeView: View {
    @Bindable var store: KotozuteStore

    @State private var body_ = ""
    @State private var isSaving = false
    @FocusState private var isFocused: Bool
    /// 1枚ずつ読む画面。書きためた分をタップすると開く。
    @State private var detail: KotozuteDetail?
    @State private var editing: Kotozute?
    @State private var editError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                editor
                    .padding(.top, 20)

                WritingHint()
                    .padding(.top, 18)

                saveButton
                    .padding(.top, 18)

                Divider()
                    .padding(.top, 32)

                myKotozuteSection
                    .padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("ことづてを書く")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $detail) { detail in
            KotozuteDetailView(detail: detail, onEdit: { editing = $0 })
        }
        .sheet(item: $editing) { item in
            WriteView(title: "書き直す", initialBody: item.body) { body in
                Task { editError = await store.edit(id: item.id, body: body) }
            }
        }
        .alert("書き直せなかった", isPresented: .constant(editError != nil)) {
            Button("とじる") { editError = nil }
        } message: {
            Text(editError ?? "")
        }
    }

    private var editor: some View {
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
    }

    private var saveButton: some View {
        Button {
            Task {
                isSaving = true
                await store.write(body_)
                isSaving = false
                body_ = ""
                isFocused = false
            }
        } label: {
            Group {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("壁に貼る").font(Theme.font(17, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canSave ? Theme.accent : Theme.inkSoft.opacity(0.4))
            .clipShape(Capsule())
        }
        .disabled(!canSave || isSaving)
    }

    /// 書きためている分。オープンまでは自分だけに見えている。
    private var myKotozuteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今週のことづて")
                .font(Theme.font(20, weight: .bold))
                .foregroundStyle(Theme.ink)

            // 「今週」がいつ閉じるのかを具体的に出す。
            // 曜日と時刻は設定で変えられるので、決め打ちの文言にはしない。
            if let nextOpenAt = store.homeState?.nextOpenAt,
               let date = nextOpenAt.date(in: store.timezone) {
                Text("\(OpenSchedule.dateTime(date, in: store.timezone))にオープン")
                    .font(Theme.font(13, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }

            if store.myKotozute.isEmpty {
                Text("ありがとうと思ったときに、ひとこと。\nそれで十分。")
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(4)
                    .padding(.top, 4)
            } else {
                Text("その日まで、自分だけに。")
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.inkSoft)

                StickyNoteList(items: store.myKotozute) { tapped in
                    detail = KotozuteDetail(
                        items: store.myKotozute,
                        startIndex: store.myKotozute.firstIndex(of: tapped) ?? 0,
                        title: "今週のことづて",
                        colorOffset: 0,
                        isEditable: true,
                        showsCompose: false
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var canSave: Bool {
        !body_.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
