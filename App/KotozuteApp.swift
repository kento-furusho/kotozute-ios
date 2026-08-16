import SwiftUI

@main
struct KotozuteApp: App {
    @State private var auth: AuthStore?
    @State private var setupError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let auth {
                    RootView(auth: auth)
                } else if let setupError {
                    Text(setupError)
                        .font(Theme.font(15))
                        .foregroundStyle(Theme.ink)
                        .padding(28)
                } else {
                    ProgressView()
                }
            }
            .tint(Theme.accent)
            .task {
                guard auth == nil, setupError == nil else { return }
                do {
                    auth = try AuthStore()
                } catch {
                    setupError = "認証の準備に失敗した。\(error.localizedDescription)"
                }
            }
        }
    }
}
