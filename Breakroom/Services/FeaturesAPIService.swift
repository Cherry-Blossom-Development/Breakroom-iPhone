import Foundation

// MARK: - Response Models

struct FeaturesResponse: Decodable {
    let features: [String]
}

// MARK: - Features API Service

enum FeaturesAPIService {

    /// Fetches the feature flags for the current user
    static func getMyFeatures() async throws -> [String] {
        let response: FeaturesResponse = try await APIClient.shared.request("/api/features/mine")
        return response.features
    }
}
