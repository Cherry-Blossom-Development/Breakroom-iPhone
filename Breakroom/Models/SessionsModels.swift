import Foundation

// MARK: - Recording State

enum RecordingState: Equatable {
    case idle
    case recording
    case saving
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
        case avgRating = "avg_rating"
        case ratingCount = "rating_count"
        case myRating = "my_rating"
    }

    /// Extract year from recordedAt or uploadedAt (format: "YYYY-MM-DD..." or ISO8601)
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

    /// Format file size for display (e.g., "1.2 MB")
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

    /// Format date for display (e.g., "2024-03-15")
    var formattedDate: String {
        let dateString = recordedAt ?? uploadedAt
        return String(dateString.prefix(10))
    }
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

// MARK: - API Request Types

struct UpdateSessionRequest: Encodable {
    let name: String?
    let recordedAt: String?

    enum CodingKeys: String, CodingKey {
        case name
        case recordedAt = "recorded_at"
    }
}

struct RateSessionRequest: Encodable {
    let rating: Int?
}
