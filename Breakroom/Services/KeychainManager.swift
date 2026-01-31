import Foundation
import Security

enum KeychainManager {
    private static let service = "com.cherryblossomdev.Breakroom"

    enum Key: String {
        case jwtToken = "jwt_token"
        case username = "username"
        case userId = "user_id"
    }

    static func save(_ value: String, for key: Key) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func clearAll() {
        for key in [Key.jwtToken, .username, .userId] {
            delete(key)
        }
    }

    static var token: String? {
        get { get(.jwtToken) }
        set {
            if let newValue {
                save(newValue, for: .jwtToken)
            } else {
                delete(.jwtToken)
            }
        }
    }

    static var bearerToken: String? {
        guard let token else { return nil }
        return "Bearer \(token)"
    }
}
