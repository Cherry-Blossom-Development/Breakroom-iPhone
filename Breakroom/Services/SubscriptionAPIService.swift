import Foundation

enum SubscriptionAPIService {
    /// Get current user's subscription status
    static func getStatus() async throws -> SubscriptionStatus {
        return try await APIClient.shared.request("/api/subscriptions/me")
    }

    /// Verify an Apple StoreKit purchase and activate subscription
    static func verifyApplePurchase(originalTransactionId: String) async throws -> AppleVerifyResponse {
        let body = AppleVerifyRequest(originalTransactionId: originalTransactionId)
        return try await APIClient.shared.request(
            "/api/subscriptions/apple/verify",
            method: "POST",
            body: body
        )
    }
}
