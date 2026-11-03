import SwiftUI

/// ペアを組んだ直後に1度だけ出す、オープンのペースを決める画面。
///
/// これまではペアを組むと「毎週 金曜 20:00」に自動で決まり、変えられるのは設定画面だけだった。
/// 周期まで選べるようになったので、始める前に一度ここで決めてもらう。
///
/// ペースはふたりで1つ。先に決めた人の設定が入り、あとから開いた人には
/// 「◯◯が決めたペース」として見せる（変えたければ変えられる）。
/// 何も触らずに「このペースにする」を押しても、決めたことは記録する
/// （そうしないと、相手の画面で「◯◯が決めた」と出せない）。
struct FirstScheduleView: View {
    @Bindable var store: KotozuteStore
    /// 閉じる（決めた・そのままにした、のどちらでも）。
    let onDone: () -> Void

    @State private var intervalWeeks = 1
    @State private var dayOfWeek = 5
    @State private var hour = 20
    @State private var minute = 0
    @State private var isChanging = false
    @State private var isSaving = false
    @State private var message: String?

    /// 相手がもう決めているか。
    private var decidedByPartner: Bool {
        guard let setBy = store.scheduleSetBy else { return false }
        return setBy == store.partnerUserID && !store.partnerUserID.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("オープンのペース")
                    .font(Theme.font(26, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 56)

                if decidedByPartner && !isChanging {
                    decidedView
                } else {
                    chooseView
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            intervalWeeks = store.openIntervalWeeks
            dayOfWeek = store.openDayOfWeek
            (hour, minute) = SchedulePicker.split(store.openTime)
        }
    }

    // MARK: - 相手が決めている

    private var decidedView: some View {
        VStack(spacing: 0) {
            Text("\(store.partnerName)が決めたペース")
                .font(Theme.font(15))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 10)

            Text(currentSummary)
                .font(Theme.font(22, weight: .bold))
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
                .padding(.top, 28)

            primaryButton("このままにする") { onDone() }
                .padding(.top, 32)

            Button("変える") {
                withAnimation(.easeInOut(duration: 0.18)) { isChanging = true }
            }
            .buttonStyle(OutlineButtonStyle())
            .padding(.top, 12)
        }
    }

    // MARK: - 自分が決める

    private var chooseView: some View {
        VStack(spacing: 0) {
            Text("ふたりのことづてが、このペースでまとまる。\nあとから設定で変えられる。")
                .font(Theme.font(15))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 10)

            SchedulePicker(
                intervalWeeks: $intervalWeeks,
                dayOfWeek: $dayOfWeek,
                hour: $hour,
                minute: $minute
            )
            .padding(.top, 28)

            if let message {
                Text(message)
                    .font(Theme.font(14))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 8)
            }

            primaryButton(isSaving ? nil : "このペースにする") {
                Task { await save() }
            }
            .disabled(isSaving)
            .padding(.top, 24)
        }
    }

    // MARK: - 部品

    private var currentSummary: String {
        SchedulePicker.summary(
            intervalWeeks: store.openIntervalWeeks,
            dayOfWeek: store.openDayOfWeek,
            time: store.openTime
        )
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        message = await store.updateSchedule(
            openDayOfWeek: dayOfWeek,
            openTime: String(format: "%02d:%02d", hour, minute),
            intervalWeeks: intervalWeeks
        )
        if message == nil { onDone() }
    }

    /// 塗りのボタン。title が nil なら保存中としてくるくるを出す。
    private func primaryButton(_ title: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let title {
                    Text(title).font(Theme.font(17, weight: .bold))
                } else {
                    ProgressView().tint(.white)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accent)
            .clipShape(Capsule())
        }
    }
}
