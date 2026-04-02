import Foundation

enum SessionsAPIService {
    // MARK: - Sessions

    /// Get all sessions for the current user
    static func getSessions() async throws -> [Session] {
        let response: SessionsResponse = try await APIClient.shared.request("/api/sessions")
        return response.sessions
    }

    /// Get sessions from band members (other users in shared bands)
    static func getBandMemberSessions() async throws -> [Session] {
        let response: SessionsResponse = try await APIClient.shared.request("/api/sessions/band-members")
        return response.sessions
    }

    /// Upload a new audio session
    static func uploadSession(
        audioData: Data,
        filename: String,
        name: String,
        recordedAt: String?,
        bandId: Int? = nil,
        sessionType: String = "band",
        instrumentId: Int? = nil
    ) async throws -> Session {
        var fields: [String: String] = ["name": name, "session_type": sessionType]
        if let recordedAt {
            fields["recorded_at"] = recordedAt
        }
        if let bandId {
            fields["band_id"] = String(bandId)
        }
        if let instrumentId {
            fields["instrument_id"] = String(instrumentId)
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

    /// Get the S3 streaming URL for a session
    static func getStreamURL(sessionId: Int) async throws -> URL {
        return try await APIClient.shared.getRedirectLocation("/api/sessions/\(sessionId)/stream")
    }

    /// Rate a session (1-10) or clear rating (nil)
    static func rateSession(sessionId: Int, rating: Int?) async throws -> SessionRatingResponse {
        let body = RateSessionRequest(rating: rating)
        return try await APIClient.shared.request(
            "/api/sessions/\(sessionId)/rate",
            method: "POST",
            body: body
        )
    }

    /// Update session details
    static func updateSession(
        sessionId: Int,
        name: String? = nil,
        recordedAt: String? = nil,
        bandId: Int? = nil,
        instrumentId: Int? = nil
    ) async throws -> Session {
        let body = UpdateSessionRequest(name: name, recordedAt: recordedAt, bandId: bandId, instrumentId: instrumentId)
        let response: SessionResponse = try await APIClient.shared.request(
            "/api/sessions/\(sessionId)",
            method: "PATCH",
            body: body
        )
        return response.session
    }

    /// Delete a session
    static func deleteSession(sessionId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/sessions/\(sessionId)",
            method: "DELETE"
        )
    }

    // MARK: - Instruments

    /// Get list of instruments
    static func getInstruments() async throws -> [Instrument] {
        let response: InstrumentsResponse = try await APIClient.shared.request("/api/instruments", authenticated: false)
        return response.instruments
    }

    // MARK: - Bands

    /// Get all bands for the current user
    static func getBands() async throws -> [Band] {
        let response: BandsResponse = try await APIClient.shared.request("/api/bands")
        return response.bands
    }

    /// Get band detail with members
    static func getBand(bandId: Int) async throws -> Band {
        let response: BandResponse = try await APIClient.shared.request("/api/bands/\(bandId)")
        return response.band
    }

    /// Create a new band
    static func createBand(name: String, description: String?) async throws -> Band {
        let body = CreateBandRequest(name: name, description: description)
        let response: BandResponse = try await APIClient.shared.request(
            "/api/bands",
            method: "POST",
            body: body
        )
        return response.band
    }

    /// Update band name/description
    static func updateBand(bandId: Int, name: String?, description: String?) async throws -> Band {
        let body = UpdateBandRequest(name: name, description: description)
        let response: BandResponse = try await APIClient.shared.request(
            "/api/bands/\(bandId)",
            method: "PATCH",
            body: body
        )
        return response.band
    }

    /// Delete a band
    static func deleteBand(bandId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/bands/\(bandId)",
            method: "DELETE"
        )
    }

    /// Invite a user to a band by handle
    static func inviteMember(bandId: Int, handle: String) async throws -> String {
        let body = InviteMemberRequest(handle: handle)
        let response: MessageResponse = try await APIClient.shared.request(
            "/api/bands/\(bandId)/invites",
            method: "POST",
            body: body
        )
        return response.message
    }

    /// Accept or decline a band invite
    static func respondToInvite(bandId: Int, action: String) async throws {
        let body = RespondToInviteRequest(action: action)
        try await APIClient.shared.requestVoid(
            "/api/bands/\(bandId)/members/me",
            method: "PATCH",
            body: body
        )
    }

    /// Remove a member from a band (or leave)
    static func removeMember(bandId: Int, userId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/bands/\(bandId)/members/\(userId)",
            method: "DELETE"
        )
    }
}
