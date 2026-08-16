import SwiftUI

/// ペア成立後の本体。デザイン案のフッター4タブ（書く／見る／壁／設定）。
///
/// アイコンは SF Symbols ではなく、デザイン案と同じ素の図形で作っている
/// （付箋・丸・四角）。記号を借りるより、モノの見た目と揃うほうを取った。
struct MainTabView: View {
    @Bindable var store: KotozuteStore
    @Bindable var auth: AuthStore
    let archiveStore: ArchiveStore

    enum Tab: CaseIterable {
        case write, read, wall, settings

        var label: String {
            switch self {
            case .write: "書く"
            case .read: "見る"
            case .wall: "壁"
            case .settings: "設定"
            }
        }
    }

    @State private var selection: Tab = .read

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
                content
            }

            footer
        }
        .background(Theme.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .write:
            // 書いたら「見る」へ戻す。書きっぱなしで同じ画面に留まらない。
            ComposeView { body in
                await store.write(body)
                selection = .read
            }
        case .read:
            HomeView(store: store, auth: auth)
        case .wall:
            ArchiveView(store: archiveStore, partnerName: store.partnerName)
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
        case .wall:
            RoundedRectangle(cornerRadius: 3)
                .stroke(tint, lineWidth: 2)
        case .settings:
            Circle()
                .stroke(tint, lineWidth: 2)
        }
    }
}

/// 「書く」タブの中身。シートではなく画面として出す。
struct ComposeView: View {
    let onSave: (String) async -> Void

    @State private var body_ = ""
    @State private var isSaving = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if body_.isEmpty {
                    Text("いいな、と思ったこと")
                        .font(Theme.font(16))
                        .foregroundStyle(Theme.ink.opacity(0.3))
                        .padding(.top, 20)
                        .padding(.leading, 20)
                }
                TextEditor(text: $body_)
                    .font(Theme.font(16))
                    .foregroundStyle(Theme.ink)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .focused($isFocused)
            }
            .frame(height: 220)
            .background(Theme.stickyPaper(at: 0).gradient)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .shadow(color: Theme.ink.opacity(0.24), radius: 9, y: 7)
            .padding(20)

            Button {
                Task {
                    isSaving = true
                    await onSave(body_)
                    isSaving = false
                    body_ = ""
                }
            } label: {
                Group {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("しまう").font(Theme.font(17, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? Theme.accent : Theme.inkSoft.opacity(0.4))
                .clipShape(Capsule())
            }
            .disabled(!canSave || isSaving)
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("ことづてを書く")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isFocused = true }
    }

    private var canSave: Bool {
        !body_.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
