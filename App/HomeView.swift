import KotozuteAPI
import SwiftUI

/// ホーム。`GET /kotozute/this-week` の状態をそのまま画面に写す。
/// 見せてよいかの判断はサーバー側で済んでいるので、ここでは出し分けだけを行う。
struct HomeView: View {
    @Bindable var store: KotozuteStore
    @Bindable var auth: AuthStore
    let archiveStore: ArchiveStore
    @State private var isWriting = false
    /// 書き直し中のことづて。書くサイクルのものだけ開ける。
    @State private var editing: Kotozute?
    @State private var editError: String?
    @State private var showsArchive = false
    @State private var showsSettings = false

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
                    .padding(.bottom, 88)
                }
            }
            .navigationTitle("ことづて")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showsArchive) {
                ArchiveView(store: archiveStore, partnerName: store.partnerName)
            }
            .navigationDestination(isPresented: $showsSettings) {
                SettingsView(store: store, auth: auth)
            }
            .task {
                #if DEBUG
                // シミュレータでの確認用。メニューを開くタップの代わり。
                //   xcrun simctl launch <udid> dev.kotozute.app --screen archive|settings
                let arguments = ProcessInfo.processInfo.arguments
                if let index = arguments.firstIndex(of: "--screen"), index + 1 < arguments.count {
                    switch arguments[index + 1] {
                    case "archive": showsArchive = true
                    case "settings": showsSettings = true
                    default: break
                    }
                }
                #endif
            }
            .toolbar { menu }
            .overlay(alignment: .bottom) { writeButton }
            .sheet(isPresented: $isWriting) {
                WriteView { body in Task { await store.write(body) } }
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
                StickyNoteList(items: items, colorOffset: 2)
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
                StickyNoteList(items: state.lastCycleMine, colorOffset: 4)
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
                // 書くサイクルのものだけ書き直せる。オープン済みは確定扱い。
                StickyNoteList(items: store.myKotozute) { editing = $0 }
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
    private var lockedCard: some View {
        infoCard {
            Text("\(store.partnerName)のことづてが、今週の分そろっている。")
                .font(Theme.font(15, weight: .medium))
                .foregroundStyle(Theme.ink)
            Text("ひとつ書くと、\(store.partnerName)のことづても見られる。")
                .font(Theme.font(14))
                .foregroundStyle(Theme.inkSoft)
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

    private var writeButton: some View {
        Button {
            isWriting = true
        } label: {
            Text("書く")
                .font(Theme.font(17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.accent)
                .clipShape(Capsule())
                .shadow(color: Theme.accent.opacity(0.3), radius: 10, y: 4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private var menu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("アーカイブ") { showsArchive = true }
                Button("設定") { showsSettings = true }
                Divider()
                Button("読み込み直す") { Task { await store.load() } }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }

    private static let openFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E) HH:mm"
        return formatter
    }()
}
