import Foundation

/// ホーム画面の出し分け。`GET /kotozute/this-week` のレスポンスだけから決まる。
///
/// 相互ロックの判定そのものはサーバーが済ませている（`canSeePartner`）。
/// ここでやるのは「どの画面を出すか」への翻訳だけで、見せてよいかの判断を上書きしない。
public struct HomeState: Sendable, Equatable {
    public enum Screen: Sendable, Equatable {
        /// 相手の分がオープン済みで、見せてよい状態。
        case partnerVisible([Kotozute])
        /// 自分は書いたが、まだオープン前。待ちの画面。
        case waitingForOpen
        /// 相手の分はオープン済みだが、自分がまだ書いていない。書けば見られる状態。
        case lockedUntilIWrite
        /// 通常のホーム。
        case plainHome
    }

    public let screen: Screen

    /// 相手の「気配」を出してよいか。相手が0枚の週は一切出さない、という仕様の担保。
    public let showsPartnerPresence: Bool

    /// 相手がいま書いているサイクルに書いた枚数。気配の付箋をこの数だけ並べる。
    /// 本文は入らない。
    public let partnerWrittenCount: Int

    /// 直前のサイクルに自分が書いた分。次のオープンまで手元で読める。
    /// 自分のものなので、ロック中でも見せてよい。
    public let lastCycleMine: [Kotozute]

    public let nextOpenAt: WallClock?

    public init(from response: ThisWeekResponse) {
        // 判断の起点はサーバーの canSeePartner。自分の枚数から推論しない。
        //
        // 「前のサイクルに書いた人は、今のサイクルが0枚でも読める」ため、
        // myKotozute が空でも canSeePartner が真になることがある。
        // 枚数から組み立て直すと、この人をロック画面に送ってしまう。
        if response.canSeePartner {
            screen = .partnerVisible(response.lastCycle.partner)
        } else if response.openStatus == .opened {
            // 相手の分はそろっているが、自分がどちらのサイクルにも書いていない。
            screen = .lockedUntilIWrite
        } else if !response.myKotozute.isEmpty {
            screen = .waitingForOpen
        } else {
            screen = .plainHome
        }

        lastCycleMine = response.lastCycle.mine
        showsPartnerPresence = response.partnerHasWritten
        partnerWrittenCount = response.partnerWrittenCount
        nextOpenAt = response.nextOpenAt
    }
}
