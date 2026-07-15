import Foundation

// MARK: - Request Models

private struct VisitRequest: Encodable {
    let visitorId: String
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
}
