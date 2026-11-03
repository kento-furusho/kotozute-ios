import SwiftUI

/// オープンのペース（周期・曜日・時刻）を選ぶ部品。
///
/// 設定画面と、ペアを組んだ直後の画面の両方で使う。選び方が2か所で
/// ずれると、同じ設定なのに見え方が違ってしまうので、1つにまとめている。
struct SchedulePicker: View {
    @Binding var intervalWeeks: Int
    @Binding var dayOfWeek: Int
    @Binding var hour: Int
    @Binding var minute: Int

    static let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 周期は週単位。何週ごとに開くか。
            Picker("周期", selection: $intervalWeeks) {
                ForEach(1...4, id: \.self) { weeks in
                    Text(Self.intervalLabel(weeks)).tag(weeks)
                }
            }
            .pickerStyle(.segmented)

            Picker("曜日", selection: $dayOfWeek) {
                ForEach(0..<7, id: \.self) { index in
                    Text(Self.weekdays[index]).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding(.top, 10)

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
        }
    }

    /// 周期の呼び方。1週は「毎週」、それより長いものは「2週ごと」のように言う。
    static func intervalLabel(_ weeks: Int) -> String {
        weeks <= 1 ? "毎週" : "\(weeks)週ごと"
    }

    /// 「毎週 金曜 20:00」の形。設定の一覧と、ペアを組んだ直後の画面で使う。
    static func summary(intervalWeeks: Int, dayOfWeek: Int, time: String) -> String {
        let day = weekdays.indices.contains(dayOfWeek) ? weekdays[dayOfWeek] : "金"
        return "\(intervalLabel(intervalWeeks)) \(day)曜 \(time)"
    }

    /// "HH:MM" を時と分に分ける。読めなければ 20:00。
    static func split(_ time: String) -> (hour: Int, minute: Int) {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return (20, 0) }
        return (hour, minute)
    }
}
