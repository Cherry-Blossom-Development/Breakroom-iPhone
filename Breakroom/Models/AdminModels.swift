import Foundation

// MARK: - Impersonation

struct ImpersonateResponse: Codable {
    let handle: String
    let displayName: String?
    let token: String?

    enum CodingKeys: String, CodingKey {
        case handle
        case displayName = "displayName"
        case token
    }
}

// MARK: - Permission Check

struct PermissionCheckResponse: Codable {
    let hasPermission: Bool

    enum CodingKeys: String, CodingKey {
        case hasPermission = "has_permission"
    }
}
