import Foundation

/// ホーム画面の出し分け。`GET /kotozute/this-week` のレスポンスだけから決まる。
///
/// 相互ロックの判定そのものはサーバーが済ませている（`canSeePartner`）。
/// ここでやるのは「どの画面を出すか」への翻訳だけで、見せてよいかの判断を上書きしない。
public struct HomeState: Sendable, Equatable {
    public enum Screen: Sendable, Equatable {
        /// 自分が1枚以上書いていて、相手の分もオープン済み。相手のことづてを見せる。
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
    /// 枚数は持たない（サーバーも返さない）。
    public let showsPartnerPresence: Bool

    public let nextOpenAt: WallClock?

    public init(from response: ThisWeekResponse) {
        let iHaveWritten = !response.myKotozute.isEmpty
        let partnerOpened = response.openStatus == .opened

        // 分岐は「自分が書いたか × 相手がオープン済みか」の2軸。
        // 本文を見せる枝だけは、自前の判定ではなくサーバーの canSeePartner に従う。
        switch (iHaveWritten, partnerOpened) {
        case (true, true) where response.canSeePartner:
            screen = .partnerVisible(response.partnerKotozute)
        case (true, true):
            // サーバーが見せないと判断した場合。本文は届いていないので待ち扱いにする。
            screen = .waitingForOpen
        case (true, false):
            screen = .waitingForOpen
        case (false, true):
            screen = .lockedUntilIWrite
        case (false, false):
            screen = .plainHome
        }

        showsPartnerPresence = response.partnerHasWritten
        nextOpenAt = response.nextOpenAt
    }
}
