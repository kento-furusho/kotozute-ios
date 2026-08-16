import SwiftUI

/// 設定。いまはオープンの曜日・時刻とサインアウトだけ。
struct SettingsView: View {
    @Bindable var store: KotozuteStore
    @Bindable var auth: AuthStore

    @State private var dayOfWeek = 5
    @State private var hour = 20
    @State private var minute = 0
    @State private var isSaving = false
    @State private var message: String?

    private static let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
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

                Divider().padding(.vertical, 32)

                Button("サインアウト") {
                    Task { await auth.signOut() }
                }
                .font(Theme.font(15))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            dayOfWeek = store.openDayOfWeek
            let parts = store.openTime.split(separator: ":")
            hour = parts.count == 2 ? Int(parts[0]) ?? 20 : 20
            minute = parts.count == 2 ? Int(parts[1]) ?? 0 : 0
        }
    }

    /// 変更が無いのに送らない。
    private var hasChanges: Bool {
        dayOfWeek != store.openDayOfWeek
            || String(format: "%02d:%02d", hour, minute) != store.openTime
    }
}
