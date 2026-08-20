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
                    RevealView(partnerName: store.partnerName, items: wrapped.items) {
                        fullScreen = .detail(partnerDetail(wrapped.items))
                    }
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

            VStack(spacing: 2) {
                Text(weekTitle)
                    .font(Theme.font(17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                if let week = wall.current {
                    Text(Self.range(of: week, in: store.timezone))
                        .font(Theme.font(11))
                        .foregroundStyle(Theme.inkSoft)
                }
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

    private var weekTitle: String {
        guard let week = wall.current else { return "今週" }
        switch week.index {
        case 0: return "今週"
        case 1: return "先週"
        default: return "\(week.index)週前"
        }
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
            section("\(store.partnerName)からのことづて") {
                StickyNoteList(items: items, colorOffset: 2) { tapped in
                    fullScreen = .detail(partnerDetail(items, startingAt: tapped))
                }
            }
            mineSection(state.lastCycleMine)

        case .lockedUntilIWrite:
            lockedCard
            mineSection(state.lastCycleMine)

        case .waitingForOpen, .plainHome:
            countdownCard
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
                section("\(store.partnerName)からのことづて") {
                    StickyNoteList(items: wall.partner, colorOffset: 2) { tapped in
                        fullScreen = .detail(KotozuteDetail(
                            items: wall.partner,
                            startIndex: wall.partner.firstIndex(of: tapped) ?? 0,
                            title: "\(store.partnerName)からのことづて",
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
            section("じぶんのことづて") {
                StickyNoteList(items: items, colorOffset: 4) { tapped in
                    fullScreen = .detail(KotozuteDetail(
                        items: items,
                        startIndex: items.firstIndex(of: tapped) ?? 0,
                        title: "じぶんのことづて",
                        colorOffset: 4,
                        isEditable: false,
                        showsCompose: false
                    ))
                }
            }
        }
    }

    // MARK: - 部品

    private func partnerDetail(_ items: [Kotozute], startingAt tapped: Kotozute? = nil) -> KotozuteDetail {
        KotozuteDetail(
            items: items,
            startIndex: tapped.flatMap { items.firstIndex(of: $0) } ?? 0,
            title: "\(store.partnerName)からのことづて",
            colorOffset: 2,
            isEditable: false,
            showsCompose: true
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

    /// 週の範囲。「8/9 – 8/16」のように出す。
    private static func range(of week: Week, in timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timezone
        formatter.dateFormat = "M/d"
        // 終わりは次のオープン時刻そのもの。表示は1日前にせず、そのまま出す。
        return "\(formatter.string(from: week.start)) – \(formatter.string(from: week.end))"
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
