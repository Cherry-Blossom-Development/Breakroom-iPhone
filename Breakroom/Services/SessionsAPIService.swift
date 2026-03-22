import Foundation

enum SessionsAPIService {
    // MARK: - Get Sessions

    /// Get all sessions for the current user
    static func getSessions() async throws -> [Session] {
        let response: SessionsResponse = try await APIClient.shared.request("/api/sessions")
        return response.sessions
    }

    // MARK: - Upload Session

    /// Upload a new audio session
    static func uploadSession(
        audioData: Data,
        filename: String,
        name: String,
        recordedAt: String?
    ) async throws -> Session {
        var fields: [String: String] = ["name": name]
        if let recordedAt {
            fields["recordedAt"] = recordedAt
        }

        let response: SessionResponse = try await APIClient.shared.uploadMultipartWithFields(
            "/api/sessions",
            fileData: audioData,
            fieldName: "audio",
            filename: filename,
            mimeType: "audio/m4a",
            additionalFields: fields
        )
        return response.session
    }

    // MARK: - Get Stream URL

    /// Get the S3 streaming URL for a session (follows 302 redirect)
    static func getStreamURL(sessionId: Int) async throws -> URL {
        return try await APIClient.shared.getRedirectLocation("/api/sessions/\(sessionId)/stream")
    }

    // MARK: - Rate Session

    /// Rate a session (1-10) or clear rating (nil)
    static func rateSession(sessionId: Int, rating: Int?) async throws -> SessionRatingResponse {
        let body = RateSessionRequest(rating: rating)
        return try await APIClient.shared.request(
            "/api/sessions/\(sessionId)/rate",
            method: "POST",
            body: body
        )
    }

    // MARK: - Update Session

    /// Update session name and/or recorded date
    static func updateSession(
        sessionId: Int,
        name: String? = nil,
        recordedAt: String? = nil
    ) async throws -> Session {
        let body = UpdateSessionRequest(name: name, recordedAt: recordedAt)
        let response: SessionResponse = try await APIClient.shared.request(
            "/api/sessions/\(sessionId)",
            method: "PUT",
            body: body
        )
        return response.session
    }

    // MARK: - Delete Session

    /// Delete a session
    static func deleteSession(sessionId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/sessions/\(sessionId)",
            method: "DELETE"
        )
    }
}
