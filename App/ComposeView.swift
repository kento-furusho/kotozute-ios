import KotozuteAPI
import SwiftUI

/// 「書く」タブ。書く場所と、いま書きためている分を同じ画面に置く。
///
/// 「見る」は相手のことづてを読む場所、「書く」は自分の分を扱う場所、という分け方。
struct ComposeView: View {
    @Bindable var store: KotozuteStore

    @State private var body_ = ""
    /// 選んだ色。空は「まだ触っていない」。
    /// そのときは巡回の次の色が選ばれているものとして扱う。
    @State private var color = ""
    @State private var isSaving = false
    @FocusState private var isFocused: Bool
    /// 1枚ずつ読む画面。書きためた分をタップすると開く。
    @State private var detail: KotozuteDetail?
    @State private var editing: Kotozute?
    @State private var editError: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 見出しとオープン日だけを先に出す。いつ閉じるのかが分かった状態で書ける。
                    header
                        .padding(.top, 20)

                    editor
                        .padding(.top, 20)

                    ColorChooser(selection: effectiveColor)
                        .padding(.top, 16)

                    WritingHint()
                        .padding(.top, 18)

                    // 書きためた分は書く場所の下。スクロールすれば見える、くらいの扱いにする。
                    myKotozuteSection
                        .padding(.top, 32)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            // 貼るボタンは画面の下に固定する。書いている途中でも位置が動かない。
            // キーボードが出たときは SwiftUI が持ち上げるので、隠れない。
            saveButton
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("ことづてを書く")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $detail) { detail in
            KotozuteDetailView(detail: detail, onEdit: { editing = $0 })
        }
        .sheet(item: $editing) { item in
            WriteView(title: "書き直す", initialBody: item.body, initialColor: item.color) { body, color in
                // 色は常に送る。選び直していなくても、開いたときの色がそのまま入る。
                Task { editError = await store.edit(id: item.id, body: body, color: color) }
            }
        }
        .alert("書き直せなかった", isPresented: .constant(editError != nil)) {
            Button("閉じる") { editError = nil }
        } message: {
            Text(editError ?? "")
        }
    }

    /// まだ色を触っていないときに選ばれている色。
    ///
    /// 壁では自分の分を colorOffset 4 で並べ、配列の位置で色が決まる。
    /// いま書いている分の次に足されるので、位置は枚数そのもの。
    /// その「次に来る色」を最初から選んでおくことで、何も触らなければ
    /// これまでどおりの巡回した見た目になる。
    private var autoPaper: Theme.StickyPaper {
        Theme.stickyPaper(at: store.myKotozute.count + 4)
    }

    private var autoHex: String {
        Theme.stickyHex(at: store.myKotozute.count + 4)
    }

    /// 画面に見せる選択。触っていなければ巡回の色、触ったらその色。
    private var effectiveColor: Binding<String> {
        Binding(
            get: { color.isEmpty ? autoHex : color },
            set: { color = $0 }
        )
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
        // 付箋は正方形に近いほうがそれらしく見える。横幅は画面に合わせて伸びるので、
        // 高さで寄せる。
        .frame(height: 290)
        // 選んだ色をそのまま下地にする。書いている紙が仕上がりと同じになる。
        .background((Theme.stickyPaper(hex: effectiveColor.wrappedValue) ?? autoPaper).gradient)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .shadow(color: Theme.ink.opacity(0.24), radius: 9, y: 7)
    }

    private var saveButton: some View {
        Button {
            Task {
                isSaving = true
                await store.write(body_, color: effectiveColor.wrappedValue)
                isSaving = false
                body_ = ""
                isFocused = false
            }
        } label: {
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
    }

    /// 見出しといつオープンするか。書く前に見えていてほしい情報だけを置く。
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("今回のことづて")
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 書きためている分。オープンまでは自分だけに見えている。
    private var myKotozuteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.myKotozute.isEmpty {
                Text("ありがとうと思ったときに、ひとこと。")
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.inkSoft)
            } else {
                StickyNoteList(items: store.myKotozute) { tapped in
                    detail = KotozuteDetail(
                        items: store.myKotozute,
                        startIndex: store.myKotozute.firstIndex(of: tapped) ?? 0,
                        title: "今回のことづて",
                        colorOffset: 0,
                        isEditable: true
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
