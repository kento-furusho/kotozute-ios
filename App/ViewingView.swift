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
    @Bindable var calendar: CalendarStore
    /// ロックされているときに「書く」へ移る。
    var onWrite: () -> Void = {}

    /// 同じ壁を2通りの切り口で見る。週は付箋で、月はカレンダーで。
    private enum Mode: String, CaseIterable {
        case notes = "付箋"
        case calendar = "カレンダー"
    }

    @State private var mode: Mode = .notes
    /// 払っている最中の横のずれ。カレンダー側と同じ手応えにする。
    @State private var dragX: CGFloat = 0
    /// 次の期間がどちら側から入ってくるか。
    @State private var incoming: Edge = .trailing

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

                VStack(spacing: 0) {
                    modeSwitcher

                    if mode == .calendar {
                        CalendarMonthView(store: store, calendar: calendar) { detail in
                            fullScreen = .detail(detail)
                        }
                    } else {
                        weekScroll
                    }
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
            .onChange(of: store.cycleStarts) { _, _ in syncWeeks() }
            .onChange(of: state.nextOpenAt) { _, _ in syncWeeks() }
            .onAppear { syncWeeks() }
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
                    KotozuteDetailView(detail: detail)
                }
            }
        }
    }

    /// 週めくりのほう。付箋をそのまま並べる、もとの見え方。
    private var weekScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                weekStepper

                // 期間そのものを差し替える。id が変わると、入ってくる週と
                // 出ていく週が別の view になり、横に流れて入れ替わる。
                weekContent
                    .id(wall.index)
                    .transition(.asymmetric(
                        insertion: .move(edge: incoming).combined(with: .opacity),
                        removal: .move(edge: incoming == .trailing ? .leading : .trailing)
                            .combined(with: .opacity)
                    ))
                    .offset(x: dragX)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .padding(.bottom, 24)
        }
        .animation(.easeOut(duration: 0.28), value: wall.index)
        // 横に払って期間を送る。上下のスクロールと同じ場所で受けるので、
        // 横の動きが縦よりはっきり大きいときだけ拾う。
        // simultaneousGesture にしないと、スクロール自体が効かなくなる。
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { drag in
                    let width = drag.translation.width
                    guard abs(width) > abs(drag.translation.height) else { return }
                    // 送れない向きは、ほとんど動かさずに端であることを伝える。
                    let canMove = width < 0 ? wall.hasNewer : wall.hasOlder
                    dragX = width * (canMove ? 0.45 : 0.12)
                }
                .onEnded { drag in
                    let width = drag.translation.width
                    let height = drag.translation.height
                    withAnimation(.easeOut(duration: 0.2)) { dragX = 0 }
                    guard abs(width) > 60, abs(width) > abs(height) * 1.5 else { return }
                    // 左に払う＝紙を左へ送る＝新しいほうへ。矢印の向きと合わせる。
                    incoming = width < 0 ? .trailing : .leading
                    Task {
                        if width < 0 {
                            await wall.showNewer()
                        } else {
                            await wall.showOlder()
                        }
                    }
                }
        )
    }

    /// 「付箋／カレンダー」の切り替え。同じ壁の切り口を選ぶだけなので、
    /// 画面の上に小さく置く。タブを増やすと「別の場所」に見える。
    private var modeSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(Mode.allCases, id: \.self) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { mode = item }
                } label: {
                    Text(item.rawValue)
                        .font(Theme.font(13, weight: mode == item ? .bold : .regular))
                        .foregroundStyle(mode == item ? Theme.ink : Theme.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if mode == item {
                                RoundedRectangle(cornerRadius: 9).fill(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Theme.line.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var state: HomeState { store.homeState ?? HomeState(from: .empty) }
    /// いちばん新しい週を見ているか。ここだけ相互ロックがかかる。
    /// 書いているサイクルの終わり＝次のオープン。壁の枠を作るのに要る。
    private func syncWeeks() {
        wall.setCycles(store.cycleStarts, nextOpen: state.nextOpenAt?.date(in: store.timezone))
    }

    // MARK: - 週の行き来

    private var weekStepper: some View {
        HStack {
            Button {
                incoming = .leading
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
                incoming = .trailing
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
        if wall.isCurrentCycle {
            currentCycle
        } else if wall.isReadingCycle {
            latestWeek
        } else {
            pastWeek
        }
    }

    /// いま書いているサイクル。まだオープン前なので、相手の本文は出せない。
    /// 相手は気配（ぼかした付箋）だけ、自分は本文をそのまま。
    ///
    /// 空のときも見出しを出す。見出し無しで「まだ無い」とだけ置くと、
    /// 上に並んだ相手のぼかし付箋と食い違って見える（無いと言っているのは
    /// 自分の分だけなのに、この期間には何も無いと読める）。
    @ViewBuilder
    private var currentCycle: some View {
        if state.showsPartnerPresence {
            section("\(store.partnerName)のことづて") {
                BlurredNotes(count: state.partnerWrittenCount)
            }
        }
        section(myTitle) {
            if store.myKotozute.isEmpty {
                emptyNote
            } else {
                StickyNoteList(items: store.myKotozute, colorOffset: 4) { tapped in
                    fullScreen = .detail(KotozuteDetail(
                        items: store.myKotozute,
                        startIndex: store.myKotozute.firstIndex(of: tapped) ?? 0,
                        title: myTitle,
                        colorOffset: 4,
                        isEditable: true
                    ))
                }
            }
        }
    }

    private var emptyNote: some View {
        Text("まだ何も書いていない。")
            .font(Theme.font(15))
            .foregroundStyle(Theme.inkSoft)
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
            // 気配はここには出さない。partnerWrittenCount が数えているのは
            // 「いま書いているサイクル」で、この画面が映しているのは
            // 読むサイクル。別の期間の話を混ぜることになる。
            if state.lastCycleMine.isEmpty {
                section(myTitle) {
                    Text("この期間は書いていない。")
                        .font(Theme.font(15))
                        .foregroundStyle(Theme.inkSoft)
                }
            } else {
                mineSection(state.lastCycleMine)
            }
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
            Text("この期間のことづては無い。")
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
                            isEditable: false
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
                        isEditable: false
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
            isEditable: false
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

    /// 罰ではなく交換なので、急かす言い方にしない。
    private var lockedCard: some View {
        infoCard {
            Text("\(store.partnerName)のことづてが、今回の分そろっている。")
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
