import KotozuteAPI
import SwiftUI

/// 「見る」画面のカレンダー。月のマス目に、ことづてのある日だけ点を打つ。
///
/// 点は上下2段で、上が自分・下が相手。左右に並べると狭いマスで潰れる。
/// 点の色はことづての色をそのまま使う。画面の中で色の意味を1つに保つため。
///
/// サイクルの区切り線は引かない。暦の月として素直に読めるほうを取った
/// （週ごとに見たいときは「付箋」側の週めくりがある）。
struct CalendarMonthView: View {
    @Bindable var store: KotozuteStore
    @Bindable var calendar: CalendarStore
    /// 日の中のことづてをタップしたとき。1枚ずつ読む画面へ渡す。
    var onOpen: (KotozuteDetail) -> Void = { _ in }

    @State private var selected: Date?
    /// 指に追わせる横のずれ。払っている最中だけ入る。
    @State private var dragX: CGFloat = 0
    /// 次の月がどちら側から入ってくるか。払った向きに合わせる。
    @State private var incoming: Edge = .trailing

    private static let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                monthStepper

                // 月そのものを差し替える。id が変わると、入ってくる月と
                // 出ていく月が別の view として扱われ、横に流れて入れ替わる。
                VStack(alignment: .leading, spacing: 0) {
                    grid
                    legend
                }
                .id(calendar.month)
                .transition(.asymmetric(
                    insertion: .move(edge: incoming).combined(with: .opacity),
                    removal: .move(edge: incoming == .trailing ? .leading : .trailing)
                        .combined(with: .opacity)
                ))
                // 払っている最中は指についてくる。動かした分をそのまま出すと
                // 端の月でも動いてしまうので、少し縮めて「引っかかり」を残す。
                .offset(x: dragX)

                if let selected {
                    selectedDay(selected)
                }
            }
            .padding(.bottom, 24)
        }
        .animation(.easeOut(duration: 0.28), value: calendar.month)
        // 週めくりと同じ操作で月を送れるようにする。
        // 縦のスクロールを殺さないよう simultaneousGesture で受ける。
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { drag in
                    let width = drag.translation.width
                    guard abs(width) > abs(drag.translation.height) else { return }
                    // 進めない向き（未来）は、さらに縮めて壁があることを伝える。
                    let resistance: CGFloat = (width < 0 && !calendar.hasNewer) ? 0.12 : 0.45
                    dragX = width * resistance
                }
                .onEnded { drag in
                    let width = drag.translation.width
                    let height = drag.translation.height
                    withAnimation(.easeOut(duration: 0.2)) { dragX = 0 }
                    guard abs(width) > 60, abs(width) > abs(height) * 1.5 else { return }
                    // 左に払う＝次の月が右から入ってくる。紙を送る向きと揃える。
                    incoming = width < 0 ? .trailing : .leading
                    Task {
                        if width < 0 {
                            await calendar.showNextMonth()
                        } else {
                            await calendar.showPreviousMonth()
                        }
                        selected = nil
                    }
                }
        )
        .task { await calendar.start(timezone: store.timezone) }
    }

    // MARK: - 月の行き来

    private var monthStepper: some View {
        HStack {
            stepButton(systemName: "chevron.left", isEnabled: true) {
                await calendar.showPreviousMonth()
            }

            Spacer()

            Text(monthTitle)
                .font(Theme.font(17, weight: .bold))
                .foregroundStyle(Theme.ink)

            Spacer()

            stepButton(systemName: "chevron.right", isEnabled: calendar.hasNewer) {
                await calendar.showNextMonth()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func stepButton(
        systemName: String,
        isEnabled: Bool,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            incoming = systemName == "chevron.right" ? .trailing : .leading
            Task {
                await action()
                selected = nil
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 32, height: 32)
                .background(Theme.line.opacity(0.7))
                .clipShape(Circle())
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
    }

    private var monthTitle: String {
        let parts = calendar.calendar.dateComponents([.year, .month], from: calendar.month)
        return "\(parts.year ?? 0)年\(parts.month ?? 0)月"
    }

    // MARK: - マス目

    private var grid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Self.weekdays, id: \.self) { day in
                    Text(day)
                        .font(Theme.font(11))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 6)

            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.timeIntervalSince1970) { date in
                        cell(date)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private func cell(_ date: Date) -> some View {
        let day = calendar.day(date)
        let isThisMonth = isInDisplayedMonth(date)
        return Button {
            // 何も無い日を開いても空の欄が出るだけなので、選ばない。
            guard !day.isEmpty else { return }
            selected = isSelected(date) ? nil : date
        } label: {
            VStack(spacing: 3) {
                dayNumber(date, isThisMonth: isThisMonth)
                dots(day.mine, colorOffset: 4)
                dots(day.partner, colorOffset: 2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dayNumber(_ date: Date, isThisMonth: Bool) -> some View {
        let number = calendar.calendar.component(.day, from: date)
        return Text("\(number)")
            .font(Theme.font(13))
            .foregroundStyle(numberColor(date, isThisMonth: isThisMonth))
            .frame(width: 24, height: 24)
            .background {
                if isToday(date) {
                    Circle().fill(Theme.accent)
                } else if isSelected(date) {
                    Circle().stroke(Theme.ink, lineWidth: 1.5)
                }
            }
    }

    private func numberColor(_ date: Date, isThisMonth: Bool) -> Color {
        if isToday(date) { return .white }
        return isThisMonth ? Theme.ink : Theme.inkSoft.opacity(0.45)
    }

    /// その日のことづてを点で表す。4枚以上は3つ＋数字にして、マスの幅に収める。
    private func dots(_ items: [Kotozute], colorOffset: Int) -> some View {
        HStack(spacing: 2.5) {
            ForEach(Array(items.prefix(3).enumerated()), id: \.element.id) { index, item in
                Circle()
                    .fill(paper(for: item, at: index, colorOffset: colorOffset).base)
                    .frame(width: 6, height: 6)
            }
            if items.count > 3 {
                Text("+\(items.count - 3)")
                    .font(Theme.font(9))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .frame(height: 7)
    }

    private func paper(for item: Kotozute, at index: Int, colorOffset: Int) -> Theme.StickyPaper {
        item.color.flatMap(Theme.stickyPaper(hex:)) ?? Theme.stickyPaper(at: index + colorOffset)
    }

    /// 凡例。点の色はことづての色なので、凡例に色を置くと嘘になる。
    /// ここで言いたいのは位置（上段か下段か）だけなので、文字だけにする。
    private var legend: some View {
        Text("上段：\(myName)　下段：\(partnerName)")
            .font(Theme.font(11))
            .foregroundStyle(Theme.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 14)
    }

    // MARK: - 選んだ日

    @ViewBuilder
    private func selectedDay(_ date: Date) -> some View {
        let day = calendar.day(date)
        VStack(alignment: .leading, spacing: 20) {
            Text(Self.dayTitle(date, in: store.timezone))
                .font(Theme.font(16, weight: .bold))
                .foregroundStyle(Theme.ink)

            if !day.mine.isEmpty {
                section(myTitle, items: day.mine, colorOffset: 4)
            }
            if !day.partner.isEmpty {
                section("\(partnerName)のことづて", items: day.partner, colorOffset: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .padding(.top, 4)
    }

    private func section(_ title: String, items: [Kotozute], colorOffset: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.font(14))
                .foregroundStyle(Theme.inkSoft)
            StickyNoteList(items: items, colorOffset: colorOffset) { tapped in
                onOpen(KotozuteDetail(
                    items: items,
                    startIndex: items.firstIndex(of: tapped) ?? 0,
                    title: title,
                    colorOffset: colorOffset,
                    // 過ぎた日の分。オープン済みなので書き直せない。
                    isEditable: false
                ))
            }
        }
    }

    // MARK: - 日付まわり

    /// マス目に並べる42日ぶん。前後の月の日も埋めて、7列の形を崩さない。
    private var weeks: [[Date]] {
        let cal = calendar.calendar
        let first = calendar.month
        let leading = cal.component(.weekday, from: first) - 1 // 日曜=0
        guard let start = cal.date(byAdding: .day, value: -leading, to: first) else { return [] }
        let dates = (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        let rows = stride(from: 0, to: dates.count, by: 7).map { Array(dates[$0..<min($0 + 7, dates.count)]) }
        // 最後の行が丸ごと翌月なら落とす。空の行があると月が長く見える。
        return rows.filter { week in week.contains(where: isInDisplayedMonth) }
    }

    private func isInDisplayedMonth(_ date: Date) -> Bool {
        calendar.calendar.isDate(date, equalTo: calendar.month, toGranularity: .month)
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.calendar.isDate(date, inSameDayAs: .now)
    }

    private func isSelected(_ date: Date) -> Bool {
        guard let selected else { return false }
        return calendar.calendar.isDate(date, inSameDayAs: selected)
    }

    private var myName: String { store.myName.isEmpty ? "じぶん" : store.myName }
    private var partnerName: String { store.partnerName.isEmpty ? "あいて" : store.partnerName }
    private var myTitle: String { "\(myName)のことづて" }

    private static func dayTitle(_ date: Date, in timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timezone
        formatter.dateFormat = "M月d日（E）"
        return formatter.string(from: date)
    }
}
