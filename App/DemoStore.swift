import Foundation
import KotozuteAPI
import Observation

/// 動きを確かめるための、通信しないインメモリのデータ元。
///
/// 認証（Cognito）がまだ繋がっていないので、当面はこれで画面を動かす。
/// `KotozuteClient` に差し替えられるよう、`ThisWeekResponse` を返す形に揃えてある。
@Observable
final class DemoStore {
    private(set) var myKotozute: [Kotozute] = []
    private(set) var partnerKotozute: [Kotozute] = []

    /// 週一バッチが相手のことづてをオープン済みにしたかどうか。
    var partnerOpened: Bool = false

    let partnerName = "あい"
    let timezone = TimeZone(identifier: "Asia/Tokyo") ?? .current

    /// サーバーの buildThisWeekResponse と同じ規則で状態を組み立てる。
    /// 相互ロックの判定を画面側で作り直さないための写し。
    var thisWeek: ThisWeekResponse {
        let canSeePartner = !myKotozute.isEmpty && partnerOpened
        return ThisWeekResponse(
            myKotozute: myKotozute,
            openStatus: partnerOpened ? .opened : .before,
            canSeePartner: canSeePartner,
            // 見せない場合は本文を持たせない。サーバーがキーごと返さないのと同じにする。
            partnerKotozute: canSeePartner ? partnerKotozute : [],
            partnerHasWritten: !partnerKotozute.isEmpty,
            nextOpenAt: WallClock("2026-08-21T20:00")
        )
    }

    var homeState: HomeState {
        HomeState(from: thisWeek)
    }

    func write(_ body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        myKotozute.append(
            Kotozute(id: UUID().uuidString, body: trimmed, createdAt: Date())
        )
    }

    // MARK: - 動作確認用

    /// 起動引数から初期状態を決める。4分岐それぞれを、手で操作せずに確認するため。
    ///   xcrun simctl launch <udid> dev.kotozute.app --demo-state locked
    init() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--demo-state"),
              index + 1 < arguments.count
        else { return }

        switch arguments[index + 1] {
        case "waiting":
            // 自分は書いた。相手はまだオープン前。
            seedMine()
            seedPartner()
        case "locked":
            // 相手はオープン済み。自分がまだ書いていない。
            seedPartner()
            partnerOpened = true
        case "visible":
            // 双方そろってオープン済み。
            seedMine()
            seedPartner()
            partnerOpened = true
        default:
            break
        }
    }

    private func seedMine() {
        myKotozute = [
            Kotozute(
                id: "m1",
                body: "急いでたのに駅まで送ってくれた。助かった。",
                createdAt: Date().addingTimeInterval(-86_400 * 3)
            )
        ]
    }

    /// 相手が書いている状態を作る。
    func seedPartner() {
        partnerKotozute = [
            Kotozute(
                id: "p1",
                body: "洗い物、いつのまにか終わってた。ありがとう。",
                createdAt: Date().addingTimeInterval(-86_400 * 2)
            ),
            Kotozute(
                id: "p2",
                body: "朝、無言でコーヒー出てきたの助かった",
                createdAt: Date().addingTimeInterval(-86_400)
            ),
        ]
    }

    func reset() {
        myKotozute = []
        partnerKotozute = []
        partnerOpened = false
    }
}
