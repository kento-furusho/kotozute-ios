import KotozuteAPI
import Observation
import SwiftUI

/// アーカイブの読み込み。月ごと・カーソルページング。
///
/// カーソルは不透明なトークンなので、中身は解釈せずそのまま次のリクエストへ渡す。
@Observable
@MainActor
final class ArchiveStore {
    private(set) var items: [Kotozute] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// nil なら終端。次ページが無い。
    private(set) var nextCursor: String?

    var whose: ArchiveWhose = .me {
        didSet { if whose != oldValue { Task { await reload() } } }
    }
    var month: Date = Date() {
        didSet { if !sameMonth(month, oldValue) { Task { await reload() } } }
    }

    private let client: KotozuteClient

    /// API の year/month は西暦。端末の暦設定（和暦など）に引きずられないよう、
    /// 年月の出し入れは常にグレゴリオ暦で行う。
    /// Calendar.current を使うと、和暦の端末で year が 8（令和8年）になり 400 で弾かれる。
    private let calendar = Calendar(identifier: .gregorian)

    init(client: KotozuteClient) {
        self.client = client
    }

    var hasMore: Bool { nextCursor != nil }

    func reload() async {
        items = []
        nextCursor = nil
        errorMessage = nil
        await loadNext()
    }

    /// 続きを読む。初回は cursor 無しで先頭から。
    func loadNext() async {
        guard !isLoading, items.isEmpty || nextCursor != nil else { return }
        isLoading = true
        defer { isLoading = false }

        let parts = calendar.dateComponents([.year, .month], from: month)
        guard let year = parts.year, let monthNumber = parts.month else { return }

        do {
            let response = try await client.archive(
                whose: whose,
                year: year,
                month: monthNumber,
                cursor: nextCursor
            )
            items.append(contentsOf: response.items)
            nextCursor = response.nextCursor
        } catch APIError.notFound {
            // ペア未成立で whose=partner を引いた場合など。
            errorMessage = "まだ見られるものがない。"
        } catch {
            errorMessage = "読み込めなかった。"
        }
    }

    private func sameMonth(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, equalTo: b, toGranularity: .month)
    }

    /// 月を前後に動かす。ここもグレゴリオ暦で計算する。
    func shiftMonth(by value: Int) {
        if let moved = calendar.date(byAdding: .month, value: value, to: month) {
            month = moved
        }
    }

    /// 先の月には進めない。
    var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: Date(), toGranularity: .month)
    }
}

/// 月ごとのアーカイブ。過去分は、オープン済みなら相手のものも見られる。
struct ArchiveView: View {
    @Bindable var store: ArchiveStore
    let partnerName: String

    @State private var detail: KotozuteDetail?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                monthPicker

                Picker("だれの", selection: $store.whose) {
                    Text("じぶん").tag(ArchiveWhose.me)
                    Text(partnerName.isEmpty ? "あいて" : partnerName).tag(ArchiveWhose.partner)
                }
                .pickerStyle(.segmented)

                if let message = store.errorMessage {
                    Text(message)
                        .font(Theme.font(15))
                        .foregroundStyle(Theme.inkSoft)
                } else if store.items.isEmpty, !store.isLoading {
                    Text("この月のことづては無い。")
                        .font(Theme.font(15))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.top, 8)
                } else {
                    StickyNoteList(
                        items: store.items,
                        colorOffset: store.whose == .me ? 0 : 2
                    ) { tapped in
                        detail = KotozuteDetail(
                            items: store.items,
                            startIndex: store.items.firstIndex(of: tapped) ?? 0,
                            title: store.whose == .me ? "じぶんのことづて" : "\(partnerName)のことづて",
                            colorOffset: store.whose == .me ? 0 : 2,
                            // 過去分は確定済み。書き直せない。
                            isEditable: false,
                            showsReply: false
                        )
                    }
                }

                if store.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if store.hasMore {
                    Button("もっと読む") {
                        Task { await store.loadNext() }
                    }
                    .font(Theme.font(15, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("アーカイブ")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $detail) { KotozuteDetailView(detail: $0) }
        .task { if store.items.isEmpty { await store.reload() } }
    }

    /// 月の行き来。同じ月の中だけを引く仕様なので、月単位で動かす。
    private var monthPicker: some View {
        HStack {
            Button {
                store.shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(Self.monthFormatter.string(from: store.month))
                .font(Theme.font(18, weight: .bold))
                .foregroundStyle(Theme.ink)

            Spacer()

            Button {
                store.shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(store.isCurrentMonth)
            .opacity(store.isCurrentMonth ? 0.3 : 1)
        }
        .foregroundStyle(Theme.inkSoft)
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        // 端末が和暦でも「2026年8月」と出す。API と同じ西暦で揃える。
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()
}
