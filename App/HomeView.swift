import KotozuteAPI
import SwiftUI

/// ホーム。`GET /kotozute/this-week` の状態をそのまま画面に写す。
/// 見せてよいかの判断はサーバー側で済んでいるので、ここでは出し分けだけを行う。
struct HomeView: View {
    @Bindable var store: KotozuteStore
    @Bindable var auth: AuthStore
    /// ロック画面から「書く」へ移るとき。タブの切り替えは親が持っている。
    var onWrite: () -> Void = {}
    /// 1枚ずつ読む画面。一覧の付箋をタップすると開く。
    @State private var detail: KotozuteDetail?
    /// 書き直し中のことづて。書くサイクルのものだけ開ける。
    @State private var editing: Kotozute?
    @State private var editError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景は画面全体に敷く。ScrollView に付けると中身の幅に縮む。
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        content
                    }
                    // VStack は子に必要な幅しか取らないので、明示的に横いっぱいに広げる。
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("ことづて")
            .navigationBarTitleDisplayMode(.inline)

            .refreshable { await store.load() }
            .fullScreenCover(item: $detail) { detail in
                KotozuteDetailView(
                    detail: detail,
                    onReply: onWrite,
                    onEdit: { editing = $0 }
                )
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
    }

    private var state: HomeState { store.homeState ?? HomeState(from: .empty) }

    @ViewBuilder
    private var content: some View {
        switch state.screen {
        case let .partnerVisible(items):
            section("\(store.partnerName)からのことづて") {
                StickyNoteList(items: items, colorOffset: 2) { tapped in
                    detail = KotozuteDetail(
                        items: items,
                        startIndex: items.firstIndex(of: tapped) ?? 0,
                        title: "\(store.partnerName)からのことづて",
                        colorOffset: 2,
                        isEditable: false,
                        showsReply: true
                    )
                }
            }
            lastCycleMineSection
            myKotozuteSection

        case .waitingForOpen:
            myKotozuteSection
            waitingCard

        case .lockedUntilIWrite:
            lockedCard
            lastCycleMineSection
            myKotozuteSection

        case .plainHome:
            myKotozuteSection
            lastCycleMineSection
        }
    }

    /// 直前のサイクルに自分が書いた分。次のオープンまでここで読める。
    /// ふたりで読む日に、自分が書いたものだけ画面から消えるのを避ける。
    @ViewBuilder
    private var lastCycleMineSection: some View {
        if !state.lastCycleMine.isEmpty {
            section("じぶんのことづて") {
                StickyNoteList(items: state.lastCycleMine, colorOffset: 4) { tapped in
                    detail = KotozuteDetail(
                        items: state.lastCycleMine,
                        startIndex: state.lastCycleMine.firstIndex(of: tapped) ?? 0,
                        title: "じぶんのことづて",
                        colorOffset: 4,
                        // オープン済みなので書き直せない。
                        isEditable: false,
                        showsReply: false
                    )
                }
            }
        }
    }

    // MARK: - 部品

    private var myKotozuteSection: some View {
        section("今週のことづて") {
            if store.myKotozute.isEmpty {
                Text("まだ何も書いていない。")
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.vertical, 8)
            } else {
                // 開いて読み、そこから書き直せる。オープン済みは確定扱いなので対象外。
                StickyNoteList(items: store.myKotozute) { tapped in
                    detail = KotozuteDetail(
                        items: store.myKotozute,
                        startIndex: store.myKotozute.firstIndex(of: tapped) ?? 0,
                        title: "今週のことづて",
                        colorOffset: 0,
                        isEditable: true,
                        showsReply: false
                    )
                }
            }
        }
    }

    /// 自分は書いたが、まだオープン前。
    /// 相手が0枚の週は気配を出さないので、文言もそれに合わせて変える。
    private var waitingCard: some View {
        infoCard {
            if state.showsPartnerPresence {
                Text("\(store.partnerName)も、今週なにか書いている。")
                    .font(Theme.font(15, weight: .medium))
                    .foregroundStyle(Theme.ink)
            }
            if let nextOpenAt = state.nextOpenAt,
               let date = nextOpenAt.date(in: store.timezone) {
                Text("次のオープンは \(Self.openFormatter.string(from: date))。")
                    .font(Theme.font(14))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    /// 相手の分はオープン済みだが、自分がまだ書いていない状態。
    /// 罰ではなく交換なので、急かす言い方にしない（デザイン案の指定）。
    private var lockedCard: some View {
        infoCard {
            Text("\(store.partnerName)のことづてが、今週の分そろっている。")
                .font(Theme.font(15, weight: .medium))
                .foregroundStyle(Theme.ink)
            Text("ひとつ書くと、\(store.partnerName)のことづても見られる。")
                .font(Theme.font(14))
                .foregroundStyle(Theme.inkSoft)

            Button {
                onWrite()
            } label: {
                Text("ことづてを書く")
                    .font(Theme.font(15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            .padding(.top, 12)

            Text("急がなくていい。気が向いたときに。")
                .font(Theme.font(12))
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    private func section(
        _ title: String,
        @ViewBuilder body: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(Theme.font(20, weight: .bold))
                .foregroundStyle(Theme.ink)
            body()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoCard(@ViewBuilder body: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            body()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1)
        )
    }

    private static let openFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E) HH:mm"
        return formatter
    }()
}
