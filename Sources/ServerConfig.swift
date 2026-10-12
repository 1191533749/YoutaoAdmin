import Foundation
import Security

struct ServerConfig: Codable {
    var siteRoot: String
    var adminEntry: String
    var username: String
    var password: String

    init(siteRoot: String = "https://r.ytw.asia",
         adminEntry: String = "FRKToHDckx.php",
         username: String = "admin",
         password: String = "") {
        self.siteRoot = siteRoot
        self.adminEntry = adminEntry
        self.username = username
        self.password = password
    }
}

enum KeychainHelper {
    static let service = "com.youtao.admin"
    static let account = "server-config"

    @discardableResult
    static func save(_ data: Data) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var query = base
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum ConfigStore {
    static let defaultsKey = "server-config"

    static func save(_ config: ServerConfig) {
        if let data = try? JSONEncoder().encode(config) {
            KeychainHelper.save(data)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    static func load() -> ServerConfig? {
        if let data = KeychainHelper.load(), let c = try? JSONDecoder().decode(ServerConfig.self, from: data) {
            return c
        }
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let c = try? JSONDecoder().decode(ServerConfig.self, from: data) {
            return c
        }
        return nil
    }

    static func clear() {
        KeychainHelper.delete()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
