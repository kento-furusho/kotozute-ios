import KotozuteAPI
import SwiftUI

/// ホーム。`GET /kotozute/this-week` の状態をそのまま画面に写す。
/// 見せてよいかの判断はサーバー側で済んでいるので、ここでは出し分けだけを行う。
struct HomeView: View {
    @Bindable var store: DemoStore
    @State private var isWriting = false

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
            .toolbar { demoMenu }
            .overlay(alignment: .bottom) { writeButton }
            .sheet(isPresented: $isWriting) {
                WriteView { body in store.write(body) }
            }
        }
    }

    private var state: HomeState { store.homeState }

    @ViewBuilder
    private var content: some View {
        switch state.screen {
        case let .partnerVisible(items):
            section("\(store.partnerName)からのことづて") {
                StickyNoteList(items: items, colorOffset: 2)
            }
            myKotozuteSection

        case .waitingForOpen:
            myKotozuteSection
            waitingCard

        case .lockedUntilIWrite:
            lockedCard
            myKotozuteSection

        case .plainHome:
            myKotozuteSection
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
                StickyNoteList(items: store.myKotozute)
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

    /// 認証が繋がるまで状態を手で切り替えるための仮メニュー。実装が進んだら外す。
    private var demoMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu("デモ") {
                Button("相手が書いた状態にする") { store.seedPartner() }
                Button(store.partnerOpened ? "オープン前に戻す" : "オープン済みにする") {
                    store.partnerOpened.toggle()
                }
                Divider()
                Button("最初から", role: .destructive) { store.reset() }
            }
            .font(Theme.font(15))
        }
    }

    private static let openFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E) HH:mm"
        return formatter
    }()
}
