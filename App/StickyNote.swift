import KotozuteAPI
import SwiftUI

/// ことづて1つの見た目。モノは付箋、呼称は「ことづて」。
struct StickyNote: View {
    let kotozute: Kotozute
    let color: Color
    /// 並べたときに単調にならないよう、わずかに傾ける。
    let tilt: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kotozute.body)
                .font(Theme.font(16))
                .foregroundStyle(Theme.ink)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(Self.dayFormatter.string(from: kotozute.createdAt))
                .font(Theme.font(12))
                .foregroundStyle(Theme.ink.opacity(0.45))
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        .rotationEffect(.degrees(tilt))
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter
    }()
}

/// 付箋を縦に並べる。傾きは位置から決めて、再描画でぶれないようにする。
struct StickyNoteList: View {
    let items: [Kotozute]
    /// 色の巡回開始位置。自分と相手で色が揃いすぎないようにずらす。
    var colorOffset: Int = 0
    /// タップで開くとき（書き直し）。nil ならタップに反応しない。
    var onTap: ((Kotozute) -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let note = StickyNote(
                    kotozute: item,
                    color: Theme.stickyColor(at: index + colorOffset),
                    tilt: index.isMultiple(of: 2) ? -0.7 : 0.8
                )
                if let onTap {
                    Button { onTap(item) } label: { note }
                        .buttonStyle(.plain)
                } else {
                    note
                }
            }
        }
    }
}
