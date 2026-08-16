import SwiftUI

@main
struct KotozuteApp: App {
    /// 認証（Cognito）が繋がるまでの仮のデータ元。
    /// 繋いだ後は KotozuteClient を包んだ本物のストアに差し替える。
    @State private var store = DemoStore()

    var body: some Scene {
        WindowGroup {
            HomeView(store: store)
                .tint(Theme.accent)
        }
    }
}
