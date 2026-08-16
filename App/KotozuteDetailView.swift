import KotozuteAPI
import SwiftUI

/// 一覧の付箋をタップしたときに開く、1枚ずつ読む画面。
///
/// デザイン案の「読む」画面に合わせている:
///   - 大きな付箋を1枚だけ出す
///   - 左右スワイプで次のことづてへ
///   - 枚数インジケータ（何枚あるかは、開いた本人には見えていい）
///   - 相手の分には「お返しに書く」、自分の分には「書き直す」
struct KotozuteDetail: Identifiable {
    let id = UUID()
    let items: [Kotozute]
    let startIndex: Int
    let title: String
    let colorOffset: Int
    /// 自分が書くサイクルに書いた分だけ書き直せる。
    let isEditable: Bool
    /// 相手の分を読んでいるとき。お返しに書く導線を出す。
    let showsReply: Bool
}

struct KotozuteDetailView: View {
    let detail: KotozuteDetail
    /// 「お返しに書く」。閉じてから書く画面へ。
    let onReply: () -> Void
    /// 「書き直す」。対象のことづてを渡す。
    let onEdit: (Kotozute) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var index: Int

    init(
        detail: KotozuteDetail,
        onReply: @escaping () -> Void = {},
        onEdit: @escaping (Kotozute) -> Void = { _ in }
    ) {
        self.detail = detail
        self.onReply = onReply
        self.onEdit = onEdit
        _index = State(initialValue: detail.startIndex)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                counter
                    .padding(.top, 8)

                TabView(selection: $index) {
                    ForEach(Array(detail.items.enumerated()), id: \.element.id) { offset, item in
                        VStack {
                            Spacer(minLength: 0)
                            StickyNote(
                                kotozute: item,
                                paper: Theme.stickyPaper(at: offset + detail.colorOffset),
                                tilt: offset.isMultiple(of: 2) ? -1.4 : 1.2,
                                tapeTilt: offset.isMultiple(of: 2) ? -2.0 : 1.6,
                                isLarge: true
                            )
                            // 内容に合わせて縮ませる。付けないと画面いっぱいに伸びて、
                            // 下半分が空白の紙になってしまう。minHeight が下限として効く。
                            .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 28)
                        .tag(offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                if detail.items.count > 1 {
                    Text("スワイプで次のことづて")
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.bottom, 12)
                }

                actions
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(detail.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("とじる") { dismiss() }
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }

    /// 何枚あるかは、開いた本人には見えてよい。
    /// 相手に対して枚数を見せない、という制約とは別の話。
    private var counter: some View {
        Text("\(index + 1) / \(detail.items.count)")
            .font(Theme.font(13, weight: .medium))
            .foregroundStyle(Theme.inkSoft)
    }

    @ViewBuilder
    private var actions: some View {
        if detail.showsReply {
            Button {
                dismiss()
                onReply()
            } label: {
                Text("お返しに書く")
                    .font(Theme.font(17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }

            Button("壁に残しておく") { dismiss() }
                .font(Theme.font(14))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 14)
        } else if detail.isEditable, detail.items.indices.contains(index) {
            let item = detail.items[index]
            Button {
                dismiss()
                onEdit(item)
            } label: {
                Text("書き直す")
                    .font(Theme.font(17, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white.opacity(0.7))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
            }
        }
    }
}
