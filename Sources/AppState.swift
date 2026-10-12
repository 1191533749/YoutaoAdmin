import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var config: ServerConfig?
    @Published var isLoggedIn = false
    @Published var isBooting = true

    var api: APIClient? {
        guard let config = config else { return nil }
        return APIClient(config: config)
    }

    func boot() async {
        config = ConfigStore.load()
        if config != nil {
            isLoggedIn = await checkLogin()
        } else {
            isLoggedIn = false
        }
        isBooting = false
    }

    func checkLogin() async -> Bool {
        guard let api = api else { return false }
        guard let data = try? await api.getRaw(path: "black/index?limit=1") else { return false }
        return ResponseParser.isLoggedIn(data)
    }

    func saveConfig(_ c: ServerConfig) {
        config = c
        ConfigStore.save(c)
    }

    func markLoggedIn() { isLoggedIn = true }

    func logout() {
        isLoggedIn = false
        if let cookies = HTTPCookieStorage.shared.cookies {
            for c in cookies { HTTPCookieStorage.shared.deleteCookie(c) }
        }
    }

    func reset() {
        logout()
        ConfigStore.clear()
        config = nil
    }
}
