import SwiftUI
import UIKit

/// 設定。いまはオープンの曜日・時刻とサインアウトだけ。
struct SettingsView: View {
    @Bindable var store: KotozuteStore
    @Bindable var auth: AuthStore

    @State private var dayOfWeek = 5
    @State private var hour = 20
    @State private var minute = 0
    @State private var isSaving = false
    @State private var message: String?
    private var push: PushStore { PushStore.shared }
    @State private var showsDeleteConfirm = false
    @State private var isDeleting = false
    @State private var name = ""
    @State private var isSavingName = false
    @State private var nameMessage: String?

    private static let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("なまえ")
                    .font(Theme.font(18, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("あいての画面に、この名前で出る。")
                    .font(Theme.font(14))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 6)

                displayName

                Divider().padding(.vertical, 28)

                Text("オープンの日")
                    .font(Theme.font(18, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("この曜日・時刻に、ふたりのことづてがまとまる。")
                    .font(Theme.font(14))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 6)

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
                        if message == nil { message = "変えた。" }
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

                Divider().padding(.vertical, 28)

                Text("お知らせ")
                    .font(Theme.font(18, weight: .bold))
                    .foregroundStyle(Theme.ink)

                notifications

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

                Divider().padding(.vertical, 28)

                Text("アカウント")
                    .font(Theme.font(18, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Button("サインアウト") {
                    Task { await auth.signOut() }
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
        .task { await push.refresh() }
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
            Text("じぶんが書いたことづてと、アカウントが消える。\nもとに戻せない。\n\nあいてが書いたことづては、あいての手元に残る。\nペアは解消され、あいてはまた誰かを招待できる。")
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
    private var notifications: some View {
        VStack(alignment: .leading, spacing: 8) {
            if push.isAuthorized {
                Text("オープンの日に、お知らせが届く。")
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.ink)
            } else if push.hasAsked {
                // 2度目からは OS がダイアログを出さないので、設定アプリへ送る。
                Text("お知らせは切ってある。")
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.ink)
                Button("iPhone の設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(Theme.font(15))
                .foregroundStyle(Theme.accent)
            } else {
                Text("オープンの日にお知らせを受け取る。")
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.ink)
                Button("お知らせを受け取る") {
                    Task {
                        await push.requestAuthorization()
                        await store.syncPushToken(push.deviceToken)
                    }
                }
                .font(Theme.font(15))
                .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 表示名。空のまま保存はできない（サーバーも 400 で弾く）。
    private var displayName: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("なまえ", text: $name)
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
                    nameMessage = await store.updateDisplayName(name) ?? "変えた。"
                    isSavingName = false
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
        }
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
