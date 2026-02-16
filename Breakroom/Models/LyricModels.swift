import Foundation

// MARK: - Song Status

enum SongStatus: String, Codable, CaseIterable {
    case idea
    case writing
    case complete
    case recorded
    case released

    var displayName: String {
        switch self {
        case .idea: return "Idea"
        case .writing: return "Writing"
        case .complete: return "Complete"
        case .recorded: return "Recorded"
        case .released: return "Released"
        }
    }
}

// MARK: - Song Visibility

enum SongVisibility: String, Codable, CaseIterable {
    case `private`
    case collaborators
    case `public`

    var displayName: String {
        switch self {
        case .private: return "Private"
        case .collaborators: return "Collaborators"
        case .public: return "Public"
        }
    }
}

// MARK: - Lyric Section Type

enum LyricSectionType: String, Codable, CaseIterable {
    case idea
    case verse
    case chorus
    case bridge
    case preChorus = "pre-chorus"
    case hook
    case intro
    case outro
    case other

    var displayName: String {
        switch self {
        case .idea: return "Idea"
        case .verse: return "Verse"
        case .chorus: return "Chorus"
        case .bridge: return "Bridge"
        case .preChorus: return "Pre-Chorus"
        case .hook: return "Hook"
        case .intro: return "Intro"
        case .outro: return "Outro"
        case .other: return "Other"
        }
    }
}

// MARK: - Lyric Status

enum LyricStatus: String, Codable, CaseIterable {
    case draft
    case inProgress = "in-progress"
    case complete
    case archived

    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .inProgress: return "In Progress"
        case .complete: return "Complete"
        case .archived: return "Archived"
        }
    }
}

// MARK: - Collaborator Role

enum CollaboratorRole: String, Codable, CaseIterable {
    case viewer
    case editor

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Song Model

struct Song: Codable, Identifiable, Hashable {
    let id: Int
    let userId: Int?
    let title: String
    let description: String?
    let genre: String?
    let status: String?
    let visibility: String?
    let createdAt: String?
    let updatedAt: String?
    let lyricCount: Int?
    let role: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, genre, status, visibility, role
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lyricCount = "lyric_count"
    }

    var songStatus: SongStatus {
        SongStatus(rawValue: status ?? "idea") ?? .idea
    }

    var songVisibility: SongVisibility {
        SongVisibility(rawValue: visibility ?? "private") ?? .private
    }

    var collaboratorRole: CollaboratorRole? {
        guard let role else { return nil }
        return CollaboratorRole(rawValue: role)
    }

    var isCollaboration: Bool {
        guard let role else { return false }
        return role != "owner"
    }
}

// MARK: - Lyric Model

struct Lyric: Codable, Identifiable, Hashable {
    let id: Int
    let userId: Int?
    let songId: Int?
    let title: String?
    let content: String
    let sectionType: String?
    let sectionOrder: Int?
    let mood: String?
    let notes: String?
    let status: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, content, mood, notes, status
        case userId = "user_id"
        case songId = "song_id"
        case sectionType = "section_type"
        case sectionOrder = "section_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var lyricSectionType: LyricSectionType {
        LyricSectionType(rawValue: sectionType ?? "idea") ?? .idea
    }

    var lyricStatus: LyricStatus {
        LyricStatus(rawValue: status ?? "draft") ?? .draft
    }

    var contentPreview: String {
        let lines = content.components(separatedBy: .newlines)
        let preview = lines.prefix(2).joined(separator: " ")
        return preview.count > 100 ? String(preview.prefix(100)) + "..." : preview
    }
}

// MARK: - Collaborator Model

struct SongCollaborator: Codable, Identifiable {
    let id: Int
    let songId: Int?
    let userId: Int?
    let role: String?
    let invitedBy: Int?
    let createdAt: String?
    let handle: String?
    let firstName: String?
    let lastName: String?

    enum CodingKeys: String, CodingKey {
        case id, role, handle
        case songId = "song_id"
        case userId = "user_id"
        case invitedBy = "invited_by"
        case createdAt = "created_at"
        case firstName = "first_name"
        case lastName = "last_name"
    }

    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? (handle ?? "Unknown") : parts.joined(separator: " ")
    }

    var collaboratorRole: CollaboratorRole {
        CollaboratorRole(rawValue: role ?? "viewer") ?? .viewer
    }
}

// MARK: - API Response Types

struct SongsResponse: Decodable {
    let songs: [Song]
}

struct SongDetailResponse: Decodable {
    let song: Song
    let lyrics: [Lyric]
    let collaborators: [SongCollaborator]
}

struct SongResponse: Decodable {
    let song: Song
}

struct LyricsResponse: Decodable {
    let lyrics: [Lyric]
}

struct LyricResponse: Decodable {
    let lyric: Lyric
}

// MARK: - API Request Types

struct CreateSongRequest: Encodable {
    let title: String
    let description: String?
    let genre: String?
    let status: String?
    let visibility: String?
}

struct UpdateSongRequest: Encodable {
    let title: String?
    let description: String?
    let genre: String?
    let status: String?
    let visibility: String?
}

struct CreateLyricRequest: Encodable {
    let songId: Int?
    let title: String?
    let content: String
    let sectionType: String?
    let sectionOrder: Int?
    let mood: String?
    let notes: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case title, content, mood, notes, status
        case songId = "song_id"
        case sectionType = "section_type"
        case sectionOrder = "section_order"
    }
}

struct UpdateLyricRequest: Encodable {
    let songId: Int?
    let title: String?
    let content: String?
    let sectionType: String?
    let sectionOrder: Int?
    let mood: String?
    let notes: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case title, content, mood, notes, status
        case songId = "song_id"
        case sectionType = "section_type"
        case sectionOrder = "section_order"
    }
}

struct AddCollaboratorRequest: Encodable {
    let handle: String
    let role: String
}

// MARK: - Shortcut Models

struct Shortcut: Codable, Identifiable, Hashable {
    let id: Int
    let userId: Int?
    let name: String
    let url: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, url
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

struct ShortcutsResponse: Decodable {
    let shortcuts: [Shortcut]
}

struct ShortcutResponse: Decodable {
    let shortcut: Shortcut
}

struct CreateShortcutRequest: Encodable {
    let name: String
    let url: String
}

struct ShortcutCheckResponse: Decodable {
    let exists: Bool
    let shortcut: Shortcut?
}
