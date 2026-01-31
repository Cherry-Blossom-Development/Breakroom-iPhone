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
