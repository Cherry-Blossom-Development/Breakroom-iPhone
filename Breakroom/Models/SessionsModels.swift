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
