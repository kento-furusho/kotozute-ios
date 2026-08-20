import SwiftUI

/// ペア成立後の本体。デザイン案のフッター4タブ（書く／見る／壁／設定）。
///
/// アイコンは SF Symbols ではなく、デザイン案と同じ素の図形で作っている
/// （付箋・格子・スライダー）。記号を借りるより、モノの見た目と揃うほうを取った。
struct MainTabView: View {
    @Bindable var store: KotozuteStore
    @Bindable var auth: AuthStore
    @Bindable var wall: WallStore

    /// 「見る」と「壁」はどちらもことづてを読む画面で違いが分かりにくかったので、
    /// 「見る」ひとつにまとめた（中身は上がいまのサイクル、下が壁）。
    enum Tab: CaseIterable {
        case write, read, settings

        var label: String {
            switch self {
            case .write: "書く"
            case .read: "見る"
            case .settings: "設定"
            }
        }
    }

    @State private var selection: Tab = .read
    /// 通知の許可と端末トークン。ここに来た＝ペアが成立している時点で尋ねる。
    private var push: PushStore { PushStore.shared }

    /// シミュレータでの確認用。タブを押す代わり。
    ///   xcrun simctl launch <udid> dev.kotozute.app --tab write|read|wall|settings
    private static var launchTab: Tab? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--tab"), index + 1 < arguments.count else { return nil }
        switch arguments[index + 1] {
        case "write": return .write
        case "read": return .read
        case "settings": return .settings
        default: return nil
        }
        #else
        return nil
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
                content
            }

            footer
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear { if let tab = Self.launchTab { selection = tab } }
        .task {
            await push.refresh()
            // 初回だけ尋ねる。2度目からは OS がダイアログを出さないので、
            // 断られていたら設定画面から案内する。
            if !push.hasAsked {
                await push.requestAuthorization()
            }
            await store.syncPushToken(push.deviceToken)
        }
        // トークンは OS から遅れて降ってくる。届いたら送る。
        .onChange(of: push.deviceToken) { _, token in
            Task { await store.syncPushToken(token) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .write:
            // 書いた分もこの画面に並ぶので、「見る」へ飛ばさずここに留まる。
            ComposeView(store: store)
        case .read:
            ViewingView(store: store, wall: wall) { selection = .write }
        case .settings:
            SettingsView(store: store, auth: auth)
        }
    }

    private var footer: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 6) {
                        icon(for: tab)
                            .frame(width: 20, height: 20)
                        Text(tab.label)
                            .font(Theme.font(10.5, weight: selection == tab ? .bold : .regular))
                            .foregroundStyle(selection == tab ? Theme.accent : Theme.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(Color(hex: 0xFFFCF6).opacity(0.95))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.ink.opacity(0.08))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func icon(for tab: Tab) -> some View {
        let tint = selection == tab ? Theme.accent : Theme.inkSoft
        switch tab {
        case .write:
            // 付箋そのもの。ここだけ色を変えず、常に紙の色でいる。
            Rectangle()
                .fill(Theme.stickyPaper(at: 0).gradient)
                .rotationEffect(.degrees(-6))
        case .read:
            // 壁に付箋が並んでいるところ。中身が壁なので、それをそのまま図にする。
            wallIcon(tint: tint, filled: selection == tab)
        case .settings:
            // 丸だと「見る」と見分けがつかなかったので、形の違うつまみにした。
            sliderIcon(tint: tint)
        }
    }

    /// 2×2 に並んだ付箋。選んでいるときは塗り、ふだんは線だけ。
    private func wallIcon(tint: Color, filled: Bool) -> some View {
        GeometryReader { geometry in
            let gap: CGFloat = 2.5
            let side = (geometry.size.width - gap) / 2
            VStack(spacing: gap) {
                ForEach(0..<2, id: \.self) { _ in
                    HStack(spacing: gap) {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1.5)
                                .strokeBorder(tint, lineWidth: filled ? side / 2 : 1.8)
                                .frame(width: side, height: side)
                        }
                    }
                }
            }
        }
    }

    /// つまみの位置をずらした3本のスライダー。
    private func sliderIcon(tint: Color) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            // 上から順に、つまみを左寄り・右寄り・中ほどに置く。
            let knobs: [CGFloat] = [0.3, 0.68, 0.45]
            VStack(spacing: 0) {
                ForEach(Array(knobs.enumerated()), id: \.offset) { _, position in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(tint)
                            .frame(height: 1.8)
                        Circle()
                            .fill(Theme.background)
                            .overlay(Circle().strokeBorder(tint, lineWidth: 1.8))
                            .frame(width: 5.5, height: 5.5)
                            .offset(x: (width - 5.5) * position)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
    }
}
