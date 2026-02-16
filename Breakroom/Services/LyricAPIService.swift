import Foundation

enum LyricAPIService {
    // MARK: - Songs

    /// Get all songs user owns or collaborates on
    static func getSongs() async throws -> [Song] {
        let response: SongsResponse = try await APIClient.shared.request("/api/lyrics/songs")
        return response.songs
    }

    /// Get single song with lyrics and collaborators
    static func getSong(id: Int) async throws -> SongDetailResponse {
        try await APIClient.shared.request("/api/lyrics/songs/\(id)")
    }

    /// Create a new song
    static func createSong(
        title: String,
        description: String?,
        genre: String?,
        status: String?,
        visibility: String?
    ) async throws -> Song {
        let body = CreateSongRequest(
            title: title,
            description: description,
            genre: genre,
            status: status,
            visibility: visibility
        )
        let response: SongResponse = try await APIClient.shared.request(
            "/api/lyrics/songs",
            method: "POST",
            body: body
        )
        return response.song
    }

    /// Update a song
    static func updateSong(
        id: Int,
        title: String?,
        description: String?,
        genre: String?,
        status: String?,
        visibility: String?
    ) async throws -> Song {
        let body = UpdateSongRequest(
            title: title,
            description: description,
            genre: genre,
            status: status,
            visibility: visibility
        )
        let response: SongResponse = try await APIClient.shared.request(
            "/api/lyrics/songs/\(id)",
            method: "PUT",
            body: body
        )
        return response.song
    }

    /// Delete a song
    static func deleteSong(id: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/lyrics/songs/\(id)",
            method: "DELETE"
        )
    }

    // MARK: - Lyrics

    /// Get all standalone lyrics (ideas not assigned to a song)
    static func getStandaloneLyrics() async throws -> [Lyric] {
        let response: LyricsResponse = try await APIClient.shared.request("/api/lyrics/standalone")
        return response.lyrics
    }

    /// Create a new lyric
    static func createLyric(
        songId: Int?,
        title: String?,
        content: String,
        sectionType: String?,
        sectionOrder: Int?,
        mood: String?,
        notes: String?,
        status: String?
    ) async throws -> Lyric {
        let body = CreateLyricRequest(
            songId: songId,
            title: title,
            content: content,
            sectionType: sectionType,
            sectionOrder: sectionOrder,
            mood: mood,
            notes: notes,
            status: status
        )
        let response: LyricResponse = try await APIClient.shared.request(
            "/api/lyrics",
            method: "POST",
            body: body
        )
        return response.lyric
    }

    /// Update a lyric
    static func updateLyric(
        id: Int,
        songId: Int?,
        title: String?,
        content: String?,
        sectionType: String?,
        sectionOrder: Int?,
        mood: String?,
        notes: String?,
        status: String?
    ) async throws -> Lyric {
        let body = UpdateLyricRequest(
            songId: songId,
            title: title,
            content: content,
            sectionType: sectionType,
            sectionOrder: sectionOrder,
            mood: mood,
            notes: notes,
            status: status
        )
        let response: LyricResponse = try await APIClient.shared.request(
            "/api/lyrics/\(id)",
            method: "PUT",
            body: body
        )
        return response.lyric
    }

    /// Delete a lyric
    static func deleteLyric(id: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/lyrics/\(id)",
            method: "DELETE"
        )
    }

    // MARK: - Collaborators

    /// Add a collaborator to a song by handle
    static func addCollaborator(songId: Int, handle: String, role: String) async throws {
        let body = AddCollaboratorRequest(handle: handle, role: role)
        try await APIClient.shared.requestVoid(
            "/api/lyrics/songs/\(songId)/collaborators",
            method: "POST",
            body: body
        )
    }

    /// Remove a collaborator from a song
    static func removeCollaborator(songId: Int, userId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/lyrics/songs/\(songId)/collaborators/\(userId)",
            method: "DELETE"
        )
    }
}

// MARK: - Shortcuts API

enum ShortcutsAPIService {
    /// Get user's shortcuts
    static func getShortcuts() async throws -> [Shortcut] {
        let response: ShortcutsResponse = try await APIClient.shared.request("/api/shortcuts")
        return response.shortcuts
    }

    /// Add a shortcut
    static func addShortcut(name: String, url: String) async throws -> Shortcut {
        let body = CreateShortcutRequest(name: name, url: url)
        let response: ShortcutResponse = try await APIClient.shared.request(
            "/api/shortcuts",
            method: "POST",
            body: body
        )
        return response.shortcut
    }

    /// Check if a shortcut exists for a URL
    static func checkShortcut(url: String) async throws -> ShortcutCheckResponse {
        let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
        return try await APIClient.shared.request("/api/shortcuts/check?url=\(encoded)")
    }

    /// Delete a shortcut
    static func deleteShortcut(id: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/shortcuts/\(id)",
            method: "DELETE"
        )
    }
}
