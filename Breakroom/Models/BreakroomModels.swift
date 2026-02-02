import Foundation

enum BlockType: String, Codable, CaseIterable, Identifiable {
    case chat
    case updates
    case calendar
    case weather
    case news
    case blog
    case placeholder

    var id: String { rawValue }

    var defaultTitle: String {
        switch self {
        case .chat: return "Chat"
        case .updates: return "Breakroom Updates"
        case .calendar: return "Calendar"
        case .weather: return "Weather"
        case .news: return "News"
        case .blog: return "Blog Posts"
        case .placeholder: return "Placeholder"
        }
    }

    var systemImage: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .updates: return "bell"
        case .calendar: return "calendar"
        case .weather: return "cloud.sun"
        case .news: return "newspaper"
        case .blog: return "doc.richtext"
        case .placeholder: return "square.dashed"
        }
    }
}

struct BreakroomBlock: Codable, Identifiable {
    let id: Int
    let blockType: String
    let title: String?
    let contentId: Int?
    let contentName: String?
    let x: Int?
    let y: Int?
    let w: Int?
    let h: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case blockType = "block_type"
        case title
        case contentId = "content_id"
        case contentName = "content_name"
        case x, y, w, h
    }

    var type: BlockType {
        BlockType(rawValue: blockType) ?? .placeholder
    }

    var displayTitle: String {
        title ?? type.defaultTitle
    }

    var heightMultiplier: Int {
        h ?? 2
    }
}

struct BreakroomLayoutResponse: Decodable {
    let blocks: [BreakroomBlock]
}

struct AddBlockRequest: Encodable {
    let blockType: String
    let title: String?
    let w: Int
    let h: Int

    enum CodingKeys: String, CodingKey {
        case blockType = "block_type"
        case title, w, h
    }
}

struct BreakroomUpdate: Codable, Identifiable {
    let id: Int?
    let title: String?
    let summary: String?
    let content: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case content
        case createdAt = "created_at"
    }

    var displayText: String {
        summary ?? content ?? title ?? ""
    }
}

struct BreakroomUpdatesResponse: Decodable {
    let updates: [BreakroomUpdate]
}

// MARK: - News

struct NewsItem: Codable, Identifiable {
    let title: String
    let link: String
    let description: String?
    let pubDate: String?
    let source: String?

    var id: String { link }

    var relativeTime: String {
        guard let dateString = pubDate else { return "" }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: dateString)

        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: dateString)
        }

        // Try RFC 2822 format (common in RSS feeds)
        if date == nil {
            let rfc = DateFormatter()
            rfc.locale = Locale(identifier: "en_US_POSIX")
            rfc.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
            date = rfc.date(from: dateString)
        }

        guard let date else { return "" }

        let now = Date()
        let diff = now.timeIntervalSince(date)
        let minutes = Int(diff / 60)
        let hours = Int(diff / 3600)

        if minutes < 60 {
            return "\(max(minutes, 1))m ago"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else {
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return f.string(from: date)
        }
    }
}

struct NewsResponse: Decodable {
    let title: String?
    let items: [NewsItem]
    let lastUpdated: String?
}
