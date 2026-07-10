import Foundation

// MARK: - Recording State

enum RecordingState: Equatable {
    case idle
    case recording
    case saving
}

// MARK: - Session Tab

enum SessionTab: String, CaseIterable {
    case bandPractice = "Band Practice"
    case individual = "Individual"
    case bands = "Bands"
}

// MARK: - Session Model

struct Session: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let s3Key: String
    let fileSize: Int64?
    let mimeType: String?
    let uploadedAt: String
    let recordedAt: String?
    let sessionType: String?
    let bandId: Int?
    let bandName: String?
    let instrumentId: Int?
    let instrumentName: String?
    let uploaderHandle: String?
    let avgRating: Double?
    let ratingCount: Int
    let myRating: Int?

    enum CodingKeys: String, CodingKey {
        case id, name
        case s3Key = "s3_key"
        case fileSize = "file_size"
        case mimeType = "mime_type"
        case uploadedAt = "uploaded_at"
        case recordedAt = "recorded_at"
        case sessionType = "session_type"
        case bandId = "band_id"
        case bandName = "band_name"
        case instrumentId = "instrument_id"
        case instrumentName = "instrument_name"
        case uploaderHandle = "uploader_handle"
        case avgRating = "avg_rating"
        case ratingCount = "rating_count"
        case myRating = "my_rating"
    }

    /// Is this an individual session?
    var isIndividual: Bool {
        sessionType == "individual"
    }

    /// Is this a mashup session?
    var isMashup: Bool {
        sessionType == "mashup"
    }

    /// Extract year from recordedAt or uploadedAt
    var year: Int {
        let dateString = recordedAt ?? uploadedAt
        if let yearStr = dateString.prefix(4).description.components(separatedBy: "-").first,
           let year = Int(yearStr) {
            return year
        }
        return Calendar.current.component(.year, from: Date())
    }

    /// Extract month (1-12) from recordedAt or uploadedAt
    var month: Int {
        let dateString = recordedAt ?? uploadedAt
        let components = dateString.prefix(10).components(separatedBy: "-")
        if components.count >= 2, let month = Int(components[1]) {
            return month
        }
        return Calendar.current.component(.month, from: Date())
    }

    /// Format file size for display
    var formattedFileSize: String {
        guard let size = fileSize else { return "" }
        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0))
        }
    }

    /// Format date for display
    var formattedDate: String {
        let dateString = recordedAt ?? uploadedAt
        return String(dateString.prefix(10))
    }
}

// MARK: - Band Model

struct Band: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let createdBy: Int?
    let createdAt: String?
    let role: String?
    let status: String?
    let memberCount: Int?
    let members: [BandMember]?
    let myRole: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, role, status, members
        case createdBy = "created_by"
        case createdAt = "created_at"
        case memberCount = "member_count"
        case myRole = "my_role"
    }

    var isOwner: Bool {
        role == "owner" || myRole == "owner"
    }

    var isActive: Bool {
        status == "active"
    }

    var isInvited: Bool {
        status == "invited"
    }
}

// MARK: - Band Member Model

struct BandMember: Codable, Identifiable, Hashable {
    let id: Int
    let handle: String
    let firstName: String?
    let lastName: String?
    let photoPath: String?
    let role: String
    let status: String
    let joinedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, handle, role, status
        case firstName = "first_name"
        case lastName = "last_name"
        case photoPath = "photo_path"
        case joinedAt = "joined_at"
    }

    var isOwner: Bool {
        role == "owner"
    }

    var displayName: String {
        if let first = firstName, !first.isEmpty {
            if let last = lastName, !last.isEmpty {
                return "\(first) \(last)"
            }
            return first
        }
        return "@\(handle)"
    }
}

// MARK: - Instrument Model

struct Instrument: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

// MARK: - API Response Types

struct SessionsResponse: Decodable {
    let sessions: [Session]
}

struct SessionResponse: Decodable {
    let session: Session
}

struct SessionRatingResponse: Decodable {
    let avgRating: Double?
    let ratingCount: Int
    let myRating: Int?

    enum CodingKeys: String, CodingKey {
        case avgRating = "avg_rating"
        case ratingCount = "rating_count"
        case myRating = "my_rating"
    }
}

struct BandsResponse: Decodable {
    let bands: [Band]
}

struct BandResponse: Decodable {
    let band: Band
}

struct InstrumentsResponse: Decodable {
    let instruments: [Instrument]
}

struct MessageResponse: Decodable {
    let message: String
}

// MARK: - API Request Types

struct UpdateSessionRequest: Encodable {
    let name: String?
    let recordedAt: String?
    let bandId: Int?
    let instrumentId: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case recordedAt = "recorded_at"
        case bandId = "band_id"
        case instrumentId = "instrument_id"
    }
}

struct RateSessionRequest: Encodable {
    let rating: Int?
}

struct CreateBandRequest: Encodable {
    let name: String
    let description: String?
}

struct UpdateBandRequest: Encodable {
    let name: String?
    let description: String?
}

struct InviteMemberRequest: Encodable {
    let handle: String
}

struct RespondToInviteRequest: Encodable {
    let action: String
}

// MARK: - Mashup Sources

struct MashupSourceEntry: Encodable {
    let sessionId: Int
    let volume: Float

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case volume
    }
}

struct RecordMashupSourcesRequest: Encodable {
    let sources: [MashupSourceEntry]
}

// MARK: - Audio Defaults

struct AudioDefaults: Codable {
    var echoCancellation: Bool
    var noiseSuppression: Bool
    var autoGainControl: Bool
    var softLimiter: Bool
    var playbackVolume: Double
    var wavPlaybackBoost: Double
    var recordingNormalization: Double
    var bitrate: Int
    var mashupBackingVolume: Double
    var mashupNewVolume: Double

    enum CodingKeys: String, CodingKey {
        case echoCancellation = "echo_cancellation"
        case noiseSuppression = "noise_suppression"
        case autoGainControl = "auto_gain_control"
        case softLimiter = "soft_limiter"
        case playbackVolume = "playback_volume"
        case wavPlaybackBoost = "wav_playback_boost"
        case recordingNormalization = "recording_normalization"
        case bitrate
        case mashupBackingVolume = "mashup_backing_volume"
        case mashupNewVolume = "mashup_new_volume"
    }

    static let `default` = AudioDefaults(
        echoCancellation: false,
        noiseSuppression: false,
        autoGainControl: false,
        softLimiter: false,
        playbackVolume: 0.75,
        wavPlaybackBoost: 3.33,
        recordingNormalization: 0.9,
        bitrate: 256000,
        mashupBackingVolume: 1.0,
        mashupNewVolume: 1.0
    )
}

// MARK: - User Device

struct UserDevice: Codable {
    let deviceToken: String
    let systemName: String
    let userName: String?
    let platform: String
    let isEmulator: Int

    enum CodingKeys: String, CodingKey {
        case deviceToken = "device_token"
        case systemName = "system_name"
        case userName = "user_name"
        case platform
        case isEmulator = "is_emulator"
    }
}

struct DeviceResponse: Decodable {
    let device: UserDevice
}

struct DeviceRegistrationRequest: Encodable {
    let deviceToken: String
    let systemName: String
    let platform: String
    let isEmulator: Bool
    let deviceInfo: [String: String]
}

struct DeviceNameRequest: Encodable {
    let userName: String?
}

// MARK: - Band Page Models

struct BandPageMember: Codable, Identifiable {
    let id: Int
    let handle: String
    let firstName: String?
    let lastName: String?
    let photoUrl: String?
    let role: String
    var instrumentIds: [Int]

    enum CodingKeys: String, CodingKey {
        case id, handle, role
        case firstName = "first_name"
        case lastName = "last_name"
        case photoUrl = "photo_url"
        case instrumentIds = "instrument_ids"
    }

    var displayName: String {
        if let first = firstName, !first.isEmpty {
            if let last = lastName, !last.isEmpty {
                return "\(first) \(last)"
            }
            return first
        }
        return "@\(handle)"
    }
}

struct BandPageSession: Codable, Identifiable {
    let id: Int
    let name: String?
    let recordedAt: String?
    let uploaderHandle: String
    let instrumentName: String?
    var onPage: Bool
    var displayOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case recordedAt = "recorded_at"
        case uploaderHandle = "uploader_handle"
        case instrumentName = "instrument_name"
        case onPage = "on_page"
        case displayOrder = "display_order"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        recordedAt = try container.decodeIfPresent(String.self, forKey: .recordedAt)
        uploaderHandle = try container.decode(String.self, forKey: .uploaderHandle)
        instrumentName = try container.decodeIfPresent(String.self, forKey: .instrumentName)
        displayOrder = try container.decodeIfPresent(Int.self, forKey: .displayOrder) ?? 999

        // Handle boolean/int for on_page
        if let boolValue = try? container.decode(Bool.self, forKey: .onPage) {
            onPage = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .onPage) {
            onPage = intValue != 0
        } else {
            onPage = false
        }
    }
}

struct BandPageData: Codable {
    let bandName: String
    var bandUrl: String?
    var story: String?
    var backgroundPhotoUrl: String?
    var backgroundColor: String?
    var isPublished: Bool
    let members: [BandPageMember]
    let instruments: [Instrument]
    let sessions: [BandPageSession]

    enum CodingKeys: String, CodingKey {
        case bandName = "band_name"
        case bandUrl = "band_url"
        case story
        case backgroundPhotoUrl = "background_photo_url"
        case backgroundColor = "background_color"
        case isPublished = "is_published"
        case members, instruments, sessions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bandName = try container.decode(String.self, forKey: .bandName)
        bandUrl = try container.decodeIfPresent(String.self, forKey: .bandUrl)
        story = try container.decodeIfPresent(String.self, forKey: .story)
        backgroundPhotoUrl = try container.decodeIfPresent(String.self, forKey: .backgroundPhotoUrl)
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        members = try container.decodeIfPresent([BandPageMember].self, forKey: .members) ?? []
        instruments = try container.decodeIfPresent([Instrument].self, forKey: .instruments) ?? []
        sessions = try container.decodeIfPresent([BandPageSession].self, forKey: .sessions) ?? []

        // Handle boolean/int for is_published
        if let boolValue = try? container.decode(Bool.self, forKey: .isPublished) {
            isPublished = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isPublished) {
            isPublished = intValue != 0
        } else {
            isPublished = false
        }
    }
}

struct UpdateBandPageRequest: Encodable {
    let bandUrl: String?
    let story: String?
    let backgroundColor: String?
    let isPublished: Bool

    enum CodingKeys: String, CodingKey {
        case bandUrl = "band_url"
        case story
        case backgroundColor = "background_color"
        case isPublished = "is_published"
    }
}

struct BandPageBackgroundResponse: Codable {
    let backgroundPhotoUrl: String?
    let backgroundPhotoKey: String?

    enum CodingKeys: String, CodingKey {
        case backgroundPhotoUrl = "background_photo_url"
        case backgroundPhotoKey = "background_photo_key"
    }
}

struct SetMemberInstrumentsRequest: Encodable {
    let instrumentIds: [Int]
}

struct SetBandPageSongsRequest: Encodable {
    let sessionIds: [Int]
}

// MARK: - Band Set Lists

struct BandSetlist: Codable, Identifiable {
    let id: Int
    let bandId: Int
    var name: String
    var songs: [String]
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case bandId = "band_id"
        case name
        case songs
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        bandId = try container.decode(Int.self, forKey: .bandId)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)

        // Songs can be null, empty array, or array of strings
        if let songsArray = try? container.decode([String].self, forKey: .songs) {
            songs = songsArray
        } else {
            songs = []
        }
    }
}

struct SetlistsResponse: Decodable {
    let setlists: [BandSetlist]
}

struct SetlistResponse: Decodable {
    let setlist: BandSetlist
}

struct CreateSetlistRequest: Encodable {
    let name: String
}

struct RenameSetlistRequest: Encodable {
    let name: String
}

struct SetSetlistSongsRequest: Encodable {
    let songs: [String]
}

struct SetlistSongsResponse: Decodable {
    let songs: [String]
}

// MARK: - Practice Suggestions

struct PracticeSuggestionsResponse: Decodable {
    let defaultBandId: Int?
    let commonNames: [String]

    enum CodingKeys: String, CodingKey {
        case defaultBandId = "default_band_id"
        case commonNames = "common_names"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultBandId = try container.decodeIfPresent(Int.self, forKey: .defaultBandId)
        commonNames = try container.decodeIfPresent([String].self, forKey: .commonNames) ?? []
    }
}

// MARK: - Pending Upload Info

struct PendingUploadInfo {
    let originalFileName: String
    let mimeType: String
    let fileURL: URL
}
