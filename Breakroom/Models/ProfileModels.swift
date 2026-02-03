import Foundation

struct UserProfile: Codable {
    let id: Int
    let handle: String
    var firstName: String?
    var lastName: String?
    let email: String?
    var bio: String?
    var workBio: String?
    var photoPath: String?
    let timezone: String?
    let city: String?
    let latitude: Double?
    let longitude: Double?
    let createdAt: String?
    let friendCount: Int
    var skills: [Skill]
    var jobs: [UserJob]

    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? handle : parts.joined(separator: " ")
    }

    var photoURL: URL? {
        guard let photoPath, !photoPath.isEmpty else { return nil }
        return URL(string: "\(APIClient.shared.baseURL)/api/uploads/\(photoPath)")
    }

    var memberSince: String {
        guard let dateString = createdAt else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: dateString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: dateString)
        }
        guard let date else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}

struct Skill: Codable, Identifiable {
    let id: Int
    let name: String
}

struct UserJob: Codable, Identifiable {
    let id: Int
    let title: String
    let company: String
    let location: String?
    let startDate: String?
    let endDate: String?
    let isCurrent: Int?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, title, company, location, description
        case startDate = "start_date"
        case endDate = "end_date"
        case isCurrent = "is_current"
    }

    var isCurrentJob: Bool {
        (isCurrent ?? 0) != 0
    }

    var formattedDateRange: String {
        let start = formatDate(startDate)
        if isCurrentJob {
            return "\(start) - Present"
        }
        let end = formatDate(endDate)
        if end.isEmpty {
            return start
        }
        return "\(start) - \(end)"
    }

    private func formatDate(_ dateStr: String?) -> String {
        guard let dateStr, !dateStr.isEmpty else { return "" }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = isoFormatter.date(from: dateStr)
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: dateStr)
        }
        if date == nil {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            date = df.date(from: dateStr)
        }
        guard let date else { return dateStr }
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: date)
    }
}

// MARK: - Response Types

struct ProfileResponse: Decodable {
    let user: UserProfile
}

struct PhotoUploadResponse: Decodable {
    let message: String?
    let photoPath: String?
}

struct SkillsSearchResponse: Decodable {
    let skills: [Skill]
}

struct SkillAddResponse: Decodable {
    let skill: Skill
}

struct JobResponse: Decodable {
    let job: UserJob
}

// MARK: - Request Types

struct UpdateProfileRequest: Encodable {
    let firstName: String
    let lastName: String
    let bio: String
    let workBio: String
}

struct AddSkillRequest: Encodable {
    let name: String
}

struct CreateJobRequest: Encodable {
    let title: String
    let company: String
    let location: String?
    let startDate: String
    let endDate: String?
    let isCurrent: Bool
    let description: String?
}

struct UpdateJobRequest: Encodable {
    let title: String
    let company: String
    let location: String?
    let startDate: String
    let endDate: String?
    let isCurrent: Bool
    let description: String?
}
