import Foundation

// MARK: - Subscription Status

struct SubscriptionStatus: Codable {
    let subscribed: Bool
    let subscription: SubscriptionInfo?
}

struct SubscriptionInfo: Codable {
    let platform: String
    let status: String
    let expiresAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case platform, status
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

// MARK: - API Request/Response Types

struct AppleVerifyRequest: Encodable {
    let originalTransactionId: String
}

struct AppleVerifyResponse: Decodable {
    let message: String
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case message
        case expiresAt = "expires_at"
    }
}
