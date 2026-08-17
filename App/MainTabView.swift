import SwiftUI

/// ペア成立後の本体。デザイン案のフッター4タブ（書く／見る／壁／設定）。
///
/// アイコンは SF Symbols ではなく、デザイン案と同じ素の図形で作っている
/// （付箋・丸・四角）。記号を借りるより、モノの見た目と揃うほうを取った。
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
            Circle()
                .stroke(tint, lineWidth: 2)
                .overlay {
                    if selection == tab {
                        Circle().fill(tint).padding(5)
                    }
                }
        case .settings:
            Circle()
                .stroke(tint, lineWidth: 2)
        }
    }
}
