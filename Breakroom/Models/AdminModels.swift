import Foundation

// MARK: - Search User (for impersonation list)

struct SearchUser: Codable, Identifiable {
    let id: Int
    let handle: String
    let displayName: String
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id
        case handle
        case displayName = "display_name"
        case email
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        handle = try container.decode(String.self, forKey: .handle)
        email = try container.decodeIfPresent(String.self, forKey: .email)

        // display_name may not exist, fall back to constructing from first/last name or handle
        if let name = try? container.decode(String.self, forKey: .displayName), !name.isEmpty {
            displayName = name
        } else {
            // Try to get first_name and last_name
            let additionalContainer = try decoder.container(keyedBy: AdditionalCodingKeys.self)
            let firstName = try additionalContainer.decodeIfPresent(String.self, forKey: .firstName)
            let lastName = try additionalContainer.decodeIfPresent(String.self, forKey: .lastName)
            let nameParts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
            displayName = nameParts.isEmpty ? handle : nameParts.joined(separator: " ")
        }
    }

    private enum AdditionalCodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

struct AllUsersResponse: Codable {
    let users: [SearchUser]
}

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

struct ImpersonateStopRequest: Encodable {
    let adminToken: String
}

// MARK: - Permission Check

struct PermissionCheckResponse: Codable {
    let hasPermission: Bool

    enum CodingKeys: String, CodingKey {
        case hasPermission = "has_permission"
    }
}
