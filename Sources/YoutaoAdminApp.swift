import SwiftUI

@main
struct YoutaoAdminApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .task { await state.boot() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            if state.isBooting {
                ProgressView("加载中…")
            } else if state.config == nil {
                SetupView()
            } else if !state.isLoggedIn {
                LoginView()
            } else {
                MainTabView()
            }
        }
    }
}
