import KotozuteAPI
import SwiftUI

/// 「見る」タブ。壁を週ごとにたどる。
///
/// もともと「いまの週」と「月ごとの一覧」が別物として並んでいたが、
/// 同じ壁を2通りの区切りで見せていて分かりにくかったので、週ひとつに揃えた。
///
/// 週の区切りはオープン日。カレンダーの週ではない（オープン曜日を変えるとずれるため）。
/// いちばん新しい週だけは相互ロックの対象なので、`this-week` の結果をそのまま使う。
struct ViewingView: View {
    @Bindable var store: KotozuteStore
    @Bindable var wall: WallStore
    /// ロックされているときに「書く」へ移る。
    var onWrite: () -> Void = {}

    private enum FullScreen: Identifiable {
        case reveal(RevealItems)
        case detail(KotozuteDetail)

        var id: String {
            switch self {
            case let .reveal(item): "reveal-\(item.id)"
            case let .detail(item): "detail-\(item.id)"
            }
        }
    }

    @State private var fullScreen: FullScreen?
    @AppStorage("seenRevealKey") private var seenRevealKey = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        weekStepper
                        weekContent
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("ことづて")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                #if DEBUG
                // 【テスト用・DEBUG限定】オープンの演出はオープン日にならないと
                // 見られないので、その場で流せるようにしている。
                // 配布ビルドには入らない（#if DEBUG）。確認が済んだら消してよい。
                ToolbarItem(placement: .topBarTrailing) {
                    Button("オープンを試す", action: playRevealForTesting)
                        .font(Theme.font(13))
                        .foregroundStyle(Theme.inkSoft)
                }
                #endif
            }
            .refreshable {
                await store.load()
                await wall.load()
            }
            .onChange(of: store.cycleStarts) { _, starts in wall.setCycles(starts) }
            .onAppear { wall.setCycles(store.cycleStarts) }
            .onChange(of: revealKey) { _, key in showRevealIfNeeded(key) }
            .onAppear { showRevealIfNeeded(revealKey) }
            .fullScreenCover(item: $fullScreen) { screen in
                switch screen {
                case let .reveal(wrapped):
                    RevealView(
                        partnerName: store.partnerName,
                        items: wrapped.items,
                        // 押して初めて「見た」と記録する。開かずに閉じた人には次にまた出す。
                        onOpened: { seenRevealKey = wrapped.items.first?.id ?? "" },
                        onRead: { fullScreen = .detail(partnerDetail(wrapped.items)) }
                    )
                case let .detail(detail):
                    KotozuteDetailView(detail: detail, onCompose: onWrite)
                }
            }
        }
    }

    private var state: HomeState { store.homeState ?? HomeState(from: .empty) }
    /// いちばん新しい週を見ているか。ここだけ相互ロックがかかる。
    private var isLatestWeek: Bool { wall.index == 0 }

    // MARK: - 週の行き来

    private var weekStepper: some View {
        HStack {
            Button {
                Task { await wall.showOlder() }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!wall.hasOlder)
            .opacity(wall.hasOlder ? 1 : 0.25)

            Spacer()

            if let week = wall.current {
                Text(OpenSchedule.range(from: week.start, to: week.end, in: store.timezone))
                    .font(Theme.font(17, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }

            Spacer()

            Button {
                Task { await wall.showNewer() }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!wall.hasNewer)
            .opacity(wall.hasNewer ? 1 : 0.25)
        }
        .foregroundStyle(Theme.inkSoft)
    }

    // MARK: - 中身

    @ViewBuilder
    private var weekContent: some View {
        if isLatestWeek {
            latestWeek
        } else {
            pastWeek
        }
    }

    /// いちばん新しい週。相互ロックの対象なので this-week の結果を使う。
    @ViewBuilder
    private var latestWeek: some View {
        switch state.screen {
        case let .partnerVisible(items):
            section("\(store.partnerName)のことづて") {
                StickyNoteList(items: items, colorOffset: 2) { tapped in
                    fullScreen = .detail(partnerDetail(items, startingAt: tapped))
                }
            }
            mineSection(state.lastCycleMine)

        case .lockedUntilIWrite:
            lockedCard
            mineSection(state.lastCycleMine)

        case .waitingForOpen, .plainHome:
            partnerPresence
            mineSection(state.lastCycleMine)
        }
    }

    /// 過去の週。オープン済みなので、ふたりぶんそのまま出す。
    @ViewBuilder
    private var pastWeek: some View {
        if wall.isLoading {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
        } else if let message = wall.errorMessage {
            Text(message)
                .font(Theme.font(15))
                .foregroundStyle(Theme.inkSoft)
        } else if wall.mine.isEmpty, wall.partner.isEmpty {
            Text("この週のことづては無い。")
                .font(Theme.font(15))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 8)
        } else {
            if !wall.partner.isEmpty {
                section("\(store.partnerName)のことづて") {
                    StickyNoteList(items: wall.partner, colorOffset: 2) { tapped in
                        fullScreen = .detail(KotozuteDetail(
                            items: wall.partner,
                            startIndex: wall.partner.firstIndex(of: tapped) ?? 0,
                            title: "\(store.partnerName)のことづて",
                            colorOffset: 2,
                            isEditable: false,
                            showsCompose: false
                        ))
                    }
                }
            }
            mineSection(wall.mine)
        }
    }

    @ViewBuilder
    private func mineSection(_ items: [Kotozute]) -> some View {
        if !items.isEmpty {
            section(myTitle) {
                StickyNoteList(items: items, colorOffset: 4) { tapped in
                    fullScreen = .detail(KotozuteDetail(
                        items: items,
                        startIndex: items.firstIndex(of: tapped) ?? 0,
                        title: myTitle,
                        colorOffset: 4,
                        isEditable: false,
                        showsCompose: false
                    ))
                }
            }
        }
    }

    /// 自分のことづての見出し。相手側が「◯◯のことづて」なので、こちらも名前で揃える。
    /// 名前がまだ取れていないときだけ「じぶん」で埋める。
    private var myTitle: String {
        store.myName.isEmpty ? "じぶんのことづて" : "\(store.myName)のことづて"
    }

    // MARK: - 部品

    private func partnerDetail(_ items: [Kotozute], startingAt tapped: Kotozute? = nil) -> KotozuteDetail {
        KotozuteDetail(
            items: items,
            startIndex: tapped.flatMap { items.firstIndex(of: $0) } ?? 0,
            title: "\(store.partnerName)のことづて",
            colorOffset: 2,
            isEditable: false,
            showsCompose: true
        )
    }

    private var revealKey: String {
        if case let .partnerVisible(items) = state.screen { return items.first?.id ?? "" }
        return ""
    }

    #if DEBUG
    /// 【テスト用】いまの状態にかかわらずオープンの演出を流す。
    ///
    /// 本物のオープンを起こすわけではない。区切りは動かないので、
    /// 閉じたあとの画面はもとの状態のまま。
    ///
    /// 相手のことづてが手元にあるときはそれを使う。無いときは見本を出す
    /// （ロック中はサーバーが本文を返さないので、手元には存在しない）。
    private func playRevealForTesting() {
        let items: [Kotozute]
        if case let .partnerVisible(visible) = state.screen, !visible.isEmpty {
            items = visible
        } else {
            items = Self.sampleItems
        }
        // 一度見た記録を消しておく。本物のオープンのときに演出が出なくなるのを防ぐ。
        seenRevealKey = ""
        fullScreen = .reveal(RevealItems(items: items))
    }

    private static let sampleItems: [Kotozute] = [
        Kotozute(id: "sample-1", body: "コーヒー淹れてくれてありがとう", createdAt: Date()),
        Kotozute(id: "sample-2", body: "昨日の話、ちゃんと聞いてくれてうれしかった", createdAt: Date()),
        Kotozute(id: "sample-3", body: "洗い物、いつのまにか終わってた", createdAt: Date()),
    ]
    #endif

    private func showRevealIfNeeded(_ key: String) {
        guard !key.isEmpty, key != seenRevealKey else { return }
        guard case let .partnerVisible(items) = state.screen else { return }
        // ここでは記録しない。実際にオープンを押したときに RevealView から記録する。
        fullScreen = .reveal(RevealItems(items: items))
    }

    /// 相手の気配。存在だけを伝える。枚数は出さない（サーバーも返さない）。
    ///
    /// もとはオープンまでの残り日数を出すカードの中にあった。カードごと消したが、
    /// 気配は仕様上ここにしか出る場所が無いので、単独で残している。
    @ViewBuilder
    private var partnerPresence: some View {
        if state.showsPartnerPresence {
            Text("\(store.partnerName)も、今週なにか書いている。")
                .font(Theme.font(15, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 罰ではなく交換なので、急かす言い方にしない。
    private var lockedCard: some View {
        infoCard {
            Text("\(store.partnerName)のことづてが、今週の分そろっている。")
                .font(Theme.font(15, weight: .medium))
                .foregroundStyle(Theme.ink)
            Text("ひとつ書くと、\(store.partnerName)のことづても見られる。")
                .font(Theme.font(14))
                .foregroundStyle(Theme.inkSoft)

            Button(action: onWrite) {
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

    private func section(_ title: String, @ViewBuilder body: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(Theme.font(20, weight: .bold))
                .foregroundStyle(Theme.ink)
            body()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoCard(@ViewBuilder body: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) { body() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
    }

}
