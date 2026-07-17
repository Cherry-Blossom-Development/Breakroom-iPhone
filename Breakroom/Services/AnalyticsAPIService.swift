import Foundation

// MARK: - Request Models

private struct VisitRequest: Encodable {
    let visitorId: String
}

private struct FeatureUsageRequest: Encodable {
    let feature: String
    let visitorId: String
}

// MARK: - Feature Tracking

/// Tracks which features have been recorded this session.
/// Each feature is only recorded once per app launch.
@MainActor
final class FeatureUsageTracker {
    static let shared = FeatureUsageTracker()
    private var recordedFeatures: Set<String> = []

    private init() {}

    /// Records feature usage if not already recorded this session.
    /// Returns true if the feature was recorded, false if already recorded.
    func recordIfNeeded(_ feature: String) async -> Bool {
        guard !recordedFeatures.contains(feature) else { return false }
        recordedFeatures.insert(feature)
        await AnalyticsAPIService.recordFeatureUsage(feature)
        return true
    }
}

// MARK: - Known Features
// Must match backend FEATURES registry in backend/routes/analytics.js

enum AnalyticsFeature: String {
    case blog
    case chat
    case friends
    case lyrics
    case sessions
    case artGallery = "art_gallery"
    case artistShowcase = "artist_showcase"
    case kanban
    case toolShed = "tool_shed"
    case companyPortal = "company_portal"
    case bandPages = "band_pages"
}

// MARK: - API Service

enum AnalyticsAPIService {
    /// Records a visit to the app. Called once per app session.
    /// This is fire-and-forget - errors are silently ignored to never disrupt UX.
    static func recordVisit() async {
        do {
            let request = VisitRequest(visitorId: KeychainManager.visitorId)
            // authenticated: true will include the bearer token if available,
            // allowing the backend to associate the visit with a user if logged in
            try await APIClient.shared.requestVoid(
                "/api/analytics/visit",
                method: "POST",
                body: request,
                authenticated: true
            )
        } catch {
            // Analytics must never disrupt the user experience
            #if DEBUG
            print("[Analytics] Failed to record visit: \(error.localizedDescription)")
            #endif
        }
    }

    /// Records feature usage. Called once per feature per app session.
    /// Use FeatureUsageTracker.shared.recordIfNeeded() to ensure deduplication.
    static func recordFeatureUsage(_ feature: String) async {
        do {
            let request = FeatureUsageRequest(feature: feature, visitorId: KeychainManager.visitorId)
            try await APIClient.shared.requestVoid(
                "/api/analytics/feature",
                method: "POST",
                body: request,
                authenticated: true
            )
        } catch {
            // Analytics must never disrupt the user experience
            #if DEBUG
            print("[Analytics] Failed to record feature usage: \(error.localizedDescription)")
            #endif
        }
    }
}
