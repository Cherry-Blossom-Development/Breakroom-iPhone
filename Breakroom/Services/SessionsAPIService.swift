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

    /// Build the streaming URL for a session (streams through backend with auth)
    static func buildStreamURL(sessionId: Int) -> URL? {
        return URL(string: "\(APIClient.shared.baseURL)/api/sessions/\(sessionId)/stream")
    }

    /// Download a session's audio file to a local temporary file
    /// - Parameter sessionId: The session ID to download
    /// - Returns: URL to the downloaded file in the temp directory
    static func downloadSession(sessionId: Int) async throws -> URL {
        guard let streamURL = buildStreamURL(sessionId: sessionId) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: streamURL)
        request.httpMethod = "GET"
        if let bearerToken = KeychainManager.bearerToken {
            request.setValue(bearerToken, forHTTPHeaderField: "Authorization")
        }

        let (tempURL, response) = try await URLSession.shared.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.serverError("Download failed with status \(httpResponse.statusCode)")
        }

        // Move to a more permanent temp location with proper extension
        let destURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("session_\(sessionId)_\(UUID().uuidString).m4a")
        try FileManager.default.moveItem(at: tempURL, to: destURL)

        return destURL
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

    /// Record the source sessions used to create a mashup
    static func recordMashupSources(sessionId: Int, sources: [MashupSourceEntry]) async throws {
        let body = RecordMashupSourcesRequest(sources: sources)
        try await APIClient.shared.requestVoid(
            "/api/sessions/\(sessionId)/sources",
            method: "POST",
            body: body
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

    // MARK: - Audio Defaults

    /// Get user's audio recording defaults
    static func getAudioDefaults() async throws -> AudioDefaults {
        return try await APIClient.shared.request("/api/user/audio-defaults")
    }

    /// Save user's audio recording defaults
    static func saveAudioDefaults(_ defaults: AudioDefaults) async throws {
        try await APIClient.shared.requestVoid(
            "/api/user/audio-defaults",
            method: "PUT",
            body: defaults
        )
    }

    // MARK: - Devices

    /// Register or refresh a device for the current user
    static func registerDevice(
        deviceToken: String,
        systemName: String,
        platform: String = "ios",
        isEmulator: Bool,
        deviceInfo: [String: String]
    ) async throws -> UserDevice {
        let body = DeviceRegistrationRequest(
            deviceToken: deviceToken,
            systemName: systemName,
            platform: platform,
            isEmulator: isEmulator,
            deviceInfo: deviceInfo
        )
        let response: DeviceResponse = try await APIClient.shared.request(
            "/api/user/devices",
            method: "POST",
            body: body
        )
        return response.device
    }

    /// Update the user-friendly name for a device
    static func saveDeviceName(deviceToken: String, userName: String?) async throws {
        let body = DeviceNameRequest(userName: userName)
        try await APIClient.shared.requestVoid(
            "/api/user/devices/\(deviceToken)/name",
            method: "PUT",
            body: body
        )
    }

    // MARK: - Band Page

    /// Get band page data for setup/editing
    static func getBandPage(bandId: Int) async throws -> BandPageData {
        try await APIClient.shared.request("/api/bands/\(bandId)/page")
    }

    /// Update band page settings
    static func updateBandPage(
        bandId: Int,
        bandUrl: String?,
        story: String?,
        backgroundColor: String?,
        isPublished: Bool
    ) async throws {
        let body = UpdateBandPageRequest(
            bandUrl: bandUrl,
            story: story,
            backgroundColor: backgroundColor,
            isPublished: isPublished
        )
        try await APIClient.shared.requestVoid(
            "/api/bands/\(bandId)/page",
            method: "PUT",
            body: body
        )
    }

    /// Upload band page background photo
    static func uploadBandPageBackground(bandId: Int, imageData: Data) async throws -> BandPageBackgroundResponse {
        try await APIClient.shared.uploadMultipart(
            "/api/bands/\(bandId)/page/background",
            fileData: imageData,
            fieldName: "photo",
            filename: "background.jpg",
            mimeType: "image/jpeg"
        )
    }

    /// Delete band page background photo
    static func deleteBandPageBackground(bandId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/bands/\(bandId)/page/background",
            method: "DELETE"
        )
    }

    /// Set instruments for a band member on the band page
    static func setBandPageMemberInstruments(bandId: Int, userId: Int, instrumentIds: [Int]) async throws {
        let body = SetMemberInstrumentsRequest(instrumentIds: instrumentIds)
        try await APIClient.shared.requestVoid(
            "/api/bands/\(bandId)/page/members/\(userId)/instruments",
            method: "PUT",
            body: body
        )
    }

    /// Set featured songs for the band page (ordered list of session IDs)
    static func setBandPageSongs(bandId: Int, sessionIds: [Int]) async throws {
        let body = SetBandPageSongsRequest(sessionIds: sessionIds)
        try await APIClient.shared.requestVoid(
            "/api/bands/\(bandId)/page/songs",
            method: "PUT",
            body: body
        )
    }

    // MARK: - Band Set Lists

    /// Get all set lists for a band
    static func getSetlists(bandId: Int) async throws -> [BandSetlist] {
        let response: SetlistsResponse = try await APIClient.shared.request("/api/bands/\(bandId)/setlists")
        return response.setlists
    }

    /// Create a new set list
    static func createSetlist(bandId: Int, name: String) async throws -> BandSetlist {
        let body = CreateSetlistRequest(name: name)
        let response: SetlistResponse = try await APIClient.shared.request(
            "/api/bands/\(bandId)/setlists",
            method: "POST",
            body: body
        )
        return response.setlist
    }

    /// Rename a set list
    static func renameSetlist(bandId: Int, setlistId: Int, name: String) async throws -> BandSetlist {
        let body = RenameSetlistRequest(name: name)
        let response: SetlistResponse = try await APIClient.shared.request(
            "/api/bands/\(bandId)/setlists/\(setlistId)",
            method: "PATCH",
            body: body
        )
        return response.setlist
    }

    /// Delete a set list
    static func deleteSetlist(bandId: Int, setlistId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/bands/\(bandId)/setlists/\(setlistId)",
            method: "DELETE"
        )
    }

    /// Update songs in a set list
    static func setSetlistSongs(bandId: Int, setlistId: Int, songs: [String]) async throws -> [String] {
        let body = SetSetlistSongsRequest(songs: songs)
        let response: SetlistSongsResponse = try await APIClient.shared.request(
            "/api/bands/\(bandId)/setlists/\(setlistId)/songs",
            method: "PUT",
            body: body
        )
        return response.songs
    }

    // MARK: - Practice Suggestions

    /// Get practice suggestions (default band and common session names)
    static func getPracticeSuggestions(bandId: Int? = nil) async throws -> PracticeSuggestionsResponse {
        var path = "/api/sessions/practice-suggestions"
        if let bandId = bandId {
            path += "?bandId=\(bandId)"
        }
        return try await APIClient.shared.request(path)
    }
}
