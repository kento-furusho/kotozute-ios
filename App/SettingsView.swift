import SwiftUI

/// 設定。ニックネーム、オープンの曜日・時刻、ペア、アカウント。
///
/// 通知の切り替えは置かない。iOS では一度断られるとアプリから再度
/// 尋ねられず、結局 iPhone の設定へ送ることになる。案内だけ置いても
/// 画面が増えるだけなので、はじめから OS の設定に任せる。
struct SettingsView: View {
    @Bindable var store: KotozuteStore
    @Bindable var auth: AuthStore
    /// ペア未成立のとき、招待画面へ戻る。
    var onInvite: () -> Void = {}

    @State private var dayOfWeek = 5
    @State private var hour = 20
    @State private var minute = 0
    @State private var isSaving = false
    @State private var message: String?
    @State private var showsDeleteConfirm = false
    @State private var isDeleting = false
    @State private var showsDissolveConfirm = false
    @State private var showsSignOutConfirm = false
    @State private var isDissolving = false
    @State private var name = ""
    @State private var isSavingName = false
    @State private var nameMessage: String?
    /// 設定はふだん「いまの値」だけ見せて、変えるときに一段開く。
    /// 入力欄をいきなり置くと、見に来ただけで触ってしまう。
    @State private var isEditingName = false
    @State private var isEditingSchedule = false

    private static let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("ニックネーム")
                    .font(Theme.font(18, weight: .bold))
                    .foregroundStyle(Theme.ink)

                if isEditingName {
                    displayName
                } else {
                    settingRow(value: store.myName.isEmpty ? "—" : store.myName) {
                        withAnimation(.easeInOut(duration: 0.18)) { isEditingName = true }
                    }
                }

                Divider().padding(.vertical, 28)

                Text("オープンの日")
                    .font(Theme.font(18, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("この曜日・時刻に、ふたりのことづてがまとまる。")
                    .font(Theme.font(14))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 6)

                if !isEditingSchedule {
                    settingRow(value: "\(Self.weekdays[store.openDayOfWeek])曜 \(store.openTime)") {
                        withAnimation(.easeInOut(duration: 0.18)) { isEditingSchedule = true }
                    }
                }

                if isEditingSchedule {
                    VStack(alignment: .leading, spacing: 0) {
                    Picker("曜日", selection: $dayOfWeek) {
                        ForEach(0..<7, id: \.self) { index in
                            Text(Self.weekdays[index]).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 18)

                    HStack(spacing: 0) {
                        Picker("時", selection: $hour) {
                            ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Text(":")
                            .font(Theme.font(20, weight: .bold))
                            .foregroundStyle(Theme.ink)

                        Picker("分", selection: $minute) {
                            // 5分刻み。細かく刻む必要のある設定ではない。
                            ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) {
                                Text(String(format: "%02d", $0)).tag($0)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 130)

                    if let message {
                        Text(message)
                            .font(Theme.font(14))
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 8)
                    }

                    Button {
                        Task {
                            isSaving = true
                            message = await store.updateSchedule(
                                openDayOfWeek: dayOfWeek,
                                openTime: String(format: "%02d:%02d", hour, minute)
                            )
                            isSaving = false
                            // うまくいったら黙って閉じる。閉じた先に新しい値が出るので、
                            // それが結果の知らせになる。「変更した。」と言い足すと、
                            // 画面が言っていることを文で繰り返すことになる。
                            if message == nil {
                                withAnimation(.easeInOut(duration: 0.18)) { isEditingSchedule = false }
                            }
                        }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("この日にする").font(Theme.font(17, weight: .bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(hasChanges ? Theme.accent : Theme.inkSoft.opacity(0.4))
                        .clipShape(Capsule())
                    }
                    .disabled(!hasChanges || isSaving)
                    .padding(.top, 16)

                        // ピッカーの下は詰まって見えるので、名前側より広く取る。
                        closeButton(topPadding: 16) { isEditingSchedule = false }
                    }
                }

                Divider().padding(.vertical, 28)

                Text("ペア")
                    .font(Theme.font(18, weight: .bold))
                    .foregroundStyle(Theme.ink)

                HStack {
                    Text(store.partnerName.isEmpty ? "—" : store.partnerName)
                        .font(Theme.font(15))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
                .padding(.vertical, 12)

                // ペア未成立でもホームに入れるようになったので、
                // ここから招待画面へ戻れないと行き止まりになる。
                if store.partnerName.isEmpty {
                    Button("ペアを組む") { onInvite() }
                        .font(Theme.font(15))
                        .foregroundStyle(Theme.accent)
                } else {
                    Button(isDissolving ? "解消中…" : "ペアを解消する") {
                        showsDissolveConfirm = true
                    }
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.inkSoft)
                    .disabled(isDissolving)
                }

                Divider().padding(.vertical, 28)

                Text("このアプリについて")
                    .font(Theme.font(18, weight: .bold))
                    .foregroundStyle(Theme.ink)

                // App Store の審査で、アプリ内から辿れることを見られる。
                // Safari で開く（アプリ内に埋め込むと、リンク先の変更に追随できない）。
                Link("利用規約", destination: Config.termsURL)
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 14)

                Link("プライバシーポリシー", destination: Config.privacyURL)
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 12)

                Link("サポート", destination: Config.supportURL)
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 12)

                // 不適切な内容を報告する手段。App Store のガイドライン 1.2 が
                // ユーザーの書いたものを見せるアプリに求めている。
                Link("問題を報告する", destination: Config.reportMailURL(userID: store.myUserID))
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 12)

                Divider().padding(.vertical, 28)

                Text("アカウント")
                    .font(Theme.font(18, weight: .bold))
                    .foregroundStyle(Theme.ink)

                // 押し間違えると登録画面まで戻され、入り直すにはパスワードが要る。
                // 取り返しはつくが手間が大きいので、一度だけ確かめる。
                Button("サインアウト") {
                    showsSignOutConfirm = true
                }
                .font(Theme.font(15))
                .foregroundStyle(Theme.accent)
                .padding(.top, 14)

                // 取り返しがつかないので、いちばん下に置いて確認を挟む。
                Button(isDeleting ? "削除中…" : "アカウントを削除") {
                    showsDeleteConfirm = true
                }
                .font(Theme.font(15))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 22)
                .disabled(isDeleting)
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        // ことづては消えない。消えるのは関係のほうだと分かるように書く。
        .alert("サインアウトする", isPresented: $showsSignOutConfirm) {
            Button("サインアウト") {
                Task {
                    await store.releasePushToken()
                    await auth.signOut()
                }
            }
            Button("やめる", role: .cancel) {}
        } message: {
            Text("本当にサインアウトしますか？")
        }
        .alert("ペアを解消する", isPresented: $showsDissolveConfirm) {
            Button("解消する", role: .destructive) {
                Task {
                    isDissolving = true
                    _ = await store.dissolvePair()
                    isDissolving = false
                }
            }
            Button("やめる", role: .cancel) {}
        } message: {
            Text("本当にペアを解消しますか？")
        }
        // 何が消えて何が残るかを、押す前に具体的に書く。
        .alert("アカウントを削除する", isPresented: $showsDeleteConfirm) {
            Button("削除する", role: .destructive) {
                Task {
                    isDeleting = true
                    if await store.deleteAccount() {
                        // 消えたあとの画面に留まらないよう、そのままサインアウトする。
                        await auth.signOut()
                    }
                    isDeleting = false
                }
            }
            Button("やめる", role: .cancel) {}
        } message: {
            Text("本当に削除しますか？この操作は取り消せません。")
        }
        .onChange(of: store.myName) { _, newName in name = newName }
        .onAppear {
            name = store.myName
            dayOfWeek = store.openDayOfWeek
            let parts = store.openTime.split(separator: ":")
            hour = parts.count == 2 ? Int(parts[0]) ?? 20 : 20
            minute = parts.count == 2 ? Int(parts[1]) ?? 0 : 0
        }
    }

    /// オープンの通知。断られていても催促にはしない。
    @ViewBuilder
    /// 表示名。空のまま保存はできない（サーバーも 400 で弾く）。
    private var displayName: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("ニックネーム", text: $name)
                .font(Theme.font(17))
                .foregroundStyle(Theme.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))

            if let nameMessage {
                Text(nameMessage)
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.inkSoft)
            }

            Button {
                Task {
                    isSavingName = true
                    let failure = await store.updateDisplayName(name)
                    isSavingName = false
                    nameMessage = failure
                    if failure == nil {
                        withAnimation(.easeInOut(duration: 0.18)) { isEditingName = false }
                    }
                }
            } label: {
                Text(isSavingName ? "保存中…" : "この名前にする")
                    .font(Theme.font(15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(canSaveName ? Theme.accent : Theme.inkSoft.opacity(0.4))
                    .clipShape(Capsule())
            }
            .disabled(!canSaveName || isSavingName)

            closeButton { isEditingName = false }
        }
        .padding(.top, 16)
    }

    /// 編集をやめる。開いている枠の中に置く。
    /// 行の側に残すと、値の無い箱に「とじる」だけが浮いて壊れて見えた。
    private func closeButton(topPadding: CGFloat = 4, _ action: @escaping () -> Void) -> some View {
        Button("閉じる") {
            withAnimation(.easeInOut(duration: 0.18)) { action() }
        }
        .font(Theme.font(14))
        .foregroundStyle(Theme.inkSoft)
        .frame(maxWidth: .infinity)
        .padding(.top, topPadding)
    }

    /// 設定の1行。ふだんは値だけ見せて、押すと編集が開く。
    ///
    /// 入力欄やピッカーをいきなり並べると、見に来ただけの人が触ってしまうし、
    /// いまどうなっているかが読み取りにくい。値を先に見せる。
    private func settingRow(
        value: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(value)
                    .font(Theme.font(17))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("変更する")
                    .font(Theme.font(15, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, 16)
    }

    /// 変わっていないのに送らない。空も送らない。
    private var canSaveName: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != store.myName
    }

    /// 変更が無いのに送らない。
    private var hasChanges: Bool {
        dayOfWeek != store.openDayOfWeek
            || String(format: "%02d:%02d", hour, minute) != store.openTime
    }
}
