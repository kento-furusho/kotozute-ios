import KotozuteAPI
import SwiftUI

/// 「見る」タブ。読むものはすべてここに集める。
///
/// もともと「見る」と「壁」に分かれていたが、どちらもことづてを読む画面で
/// 違いが分かりにくかったので、ひとつにまとめた。
///
///   上：いまのサイクル（相互ロックの対象。this-week が返す分）
///   下：壁（読み終えたサイクル。月ごとにたどる）
///
/// 上下を分けているのは扱いが違うから。上はロックがかかり、下はかからない。
struct ViewingView: View {
    @Bindable var store: KotozuteStore
    @Bindable var archiveStore: ArchiveStore
    /// ロックされているときに「書く」へ移る。
    var onWrite: () -> Void = {}

    /// 全画面で出すもの。fullScreenCover を重ねると互いに潰し合うのでひとつにまとめる。
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
    /// 演出を出したサイクルの目印。相手の分の先頭 id をそのまま使う。
    @AppStorage("seenRevealKey") private var seenRevealKey = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        currentCycle

                        Divider()

                        wall
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("ことづて")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await store.load()
                await archiveStore.reload()
            }
            .onChange(of: revealKey) { _, key in showRevealIfNeeded(key) }
            .onAppear { showRevealIfNeeded(revealKey) }
            .fullScreenCover(item: $fullScreen) { screen in
                switch screen {
                case let .reveal(wrapped):
                    RevealView(partnerName: store.partnerName, items: wrapped.items) {
                        fullScreen = .detail(partnerDetail(wrapped.items))
                    }
                case let .detail(detail):
                    KotozuteDetailView(detail: detail, onReply: onWrite)
                }
            }
        }
    }

    private var state: HomeState { store.homeState ?? HomeState(from: .empty) }

    // MARK: - いまのサイクル

    @ViewBuilder
    private var currentCycle: some View {
        switch state.screen {
        case let .partnerVisible(items):
            section("\(store.partnerName)からのことづて") {
                StickyNoteList(items: items, colorOffset: 2) { tapped in
                    fullScreen = .detail(partnerDetail(items, startingAt: tapped))
                }
            }
            lastCycleMineSection

        case .waitingForOpen, .plainHome:
            countdownCard
            lastCycleMineSection

        case .lockedUntilIWrite:
            lockedCard
            lastCycleMineSection
        }
    }

    /// 直前のサイクルに自分が書いた分。次のオープンまでここで読める。
    @ViewBuilder
    private var lastCycleMineSection: some View {
        if !state.lastCycleMine.isEmpty {
            section("じぶんのことづて") {
                StickyNoteList(items: state.lastCycleMine, colorOffset: 4) { tapped in
                    fullScreen = .detail(KotozuteDetail(
                        items: state.lastCycleMine,
                        startIndex: state.lastCycleMine.firstIndex(of: tapped) ?? 0,
                        title: "じぶんのことづて",
                        colorOffset: 4,
                        isEditable: false,
                        showsReply: false
                    ))
                }
            }
        }
    }

    // MARK: - 壁

    private var wall: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("壁")
                .font(Theme.font(20, weight: .bold))
                .foregroundStyle(Theme.ink)

            Text("読み終えたことづて。月ごとにたどれる。")
                .font(Theme.font(13))
                .foregroundStyle(Theme.inkSoft)

            ArchiveBrowser(store: archiveStore, partnerName: store.partnerName) { items, tapped in
                fullScreen = .detail(KotozuteDetail(
                    items: items,
                    startIndex: items.firstIndex(of: tapped) ?? 0,
                    title: archiveStore.whose == .me ? "じぶんのことづて" : "\(store.partnerName)のことづて",
                    colorOffset: archiveStore.whose == .me ? 0 : 2,
                    isEditable: false,
                    showsReply: false
                ))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 部品

    private func partnerDetail(_ items: [Kotozute], startingAt tapped: Kotozute? = nil) -> KotozuteDetail {
        KotozuteDetail(
            items: items,
            startIndex: tapped.flatMap { items.firstIndex(of: $0) } ?? 0,
            title: "\(store.partnerName)からのことづて",
            colorOffset: 2,
            isEditable: false,
            showsReply: true
        )
    }

    private var revealKey: String {
        if case let .partnerVisible(items) = state.screen { return items.first?.id ?? "" }
        return ""
    }

    private func showRevealIfNeeded(_ key: String) {
        guard !key.isEmpty, key != seenRevealKey else { return }
        guard case let .partnerVisible(items) = state.screen else { return }
        seenRevealKey = key
        fullScreen = .reveal(RevealItems(items: items))
    }

    /// 次のオープンまで。急かす表示ではなく、待つ時間そのものを見せる。
    @ViewBuilder
    private var countdownCard: some View {
        if let nextOpenAt = state.nextOpenAt,
           let date = nextOpenAt.date(in: store.timezone) {
            infoCard {
                Text(Self.openLabel(for: date, in: store.timezone))
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(Theme.accent)

                Text(Self.remaining(until: date, in: store.timezone))
                    .font(Theme.font(22, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("\(Self.openFormatter.string(from: date))にオープン。")
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.inkSoft)

                if state.showsPartnerPresence {
                    Text("\(store.partnerName)も、今週なにか書いている。")
                        .font(Theme.font(14, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 8)
                }
            }
        }
    }

    /// 相手の分はそろっているが、自分がまだ書いていない状態。
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

    private static func openLabel(for date: Date, in timezone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let names = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
        let weekday = calendar.component(.weekday, from: date) - 1
        return "\(names[max(0, min(6, weekday))]) OPEN"
    }

    private static func remaining(until date: Date, in timezone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        return days <= 0 ? "今日オープン" : "オープンまで あと\(days)日"
    }

    private static let openFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "M月d日(E) HH:mm"
        return formatter
    }()
}
