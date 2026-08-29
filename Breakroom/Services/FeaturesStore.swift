import Foundation

/// Global store for user feature flags.
/// Features are loaded from the backend after login and used to gate access to
/// experimental or limited-access features (e.g., "games").
@MainActor
@Observable
final class FeaturesStore {
    static let shared = FeaturesStore()

    private(set) var enabled: Set<String> = []
    private(set) var isLoaded = false

    private init() {}

    /// Check if a feature is enabled for the current user.
    func has(_ key: String) -> Bool {
        enabled.contains(key)
    }

    /// Set the enabled features (called after loading from API).
    func setEnabled(_ keys: [String]) {
        enabled = Set(keys)
        isLoaded = true
    }

    /// Clear all features (called on logout).
    func clear() {
        enabled = []
        isLoaded = false
    }

    /// Load features from the backend.
    func loadFeatures() async {
        do {
            let features = try await FeaturesAPIService.getMyFeatures()
            setEnabled(features)
        } catch {
            // Non-fatal — user just won't see gated features
            print("[FeaturesStore] Failed to load features: \(error.localizedDescription)")
            isLoaded = true
        }
    }
}

// MARK: - API Service

private struct FeaturesResponse: Codable {
    let features: [String]
}

enum FeaturesAPIService {
    /// GET /api/features/mine — returns array of enabled feature keys for the current user.
    static func getMyFeatures() async throws -> [String] {
        let response: FeaturesResponse = try await APIClient.shared.request("/api/features/mine")
        return response.features
    }
}
