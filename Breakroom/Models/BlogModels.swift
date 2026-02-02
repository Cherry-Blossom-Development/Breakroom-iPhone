import Foundation

struct BlogPost: Codable, Identifiable {
    let id: Int
    let title: String
    let content: String?
    let isPublished: Int?
    let createdAt: String?
    let updatedAt: String?
    let authorId: Int?
    let authorHandle: String?
    let authorFirstName: String?
    let authorLastName: String?
    let authorPhoto: String?

    enum CodingKeys: String, CodingKey {
        case id, title, content
        case isPublished = "is_published"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case authorId = "author_id"
        case authorHandle = "author_handle"
        case authorFirstName = "author_first_name"
        case authorLastName = "author_last_name"
        case authorPhoto = "author_photo"
    }

    var authorDisplayName: String {
        let parts = [authorFirstName, authorLastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? (authorHandle ?? "Unknown") : parts.joined(separator: " ")
    }

    var plainTextPreview: String {
        guard let content else { return "" }
        return content
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var firstImageURL: URL? {
        guard let content else { return nil }
        guard let range = content.range(of: #"<img[^>]+src\s*=\s*"([^"]+)""#, options: .regularExpression) else {
            return nil
        }
        let match = String(content[range])
        guard let srcRange = match.range(of: #"src\s*=\s*"([^"]+)""#, options: .regularExpression) else {
            return nil
        }
        let srcAttr = String(match[srcRange])
        let urlString = srcAttr
            .replacingOccurrences(of: #"src\s*=\s*""#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "\"", with: "")

        if urlString.hasPrefix("http") {
            return URL(string: urlString)
        } else {
            return URL(string: "\(APIClient.shared.baseURL)\(urlString)")
        }
    }

    var relativeDate: String {
        guard let dateString = updatedAt ?? createdAt else { return "" }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: dateString)

        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: dateString)
        }

        guard let date else { return "" }

        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0

        if days < 7 {
            return "\(days)d ago"
        }

        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

struct BlogFeedResponse: Decodable {
    let posts: [BlogPost]
}
