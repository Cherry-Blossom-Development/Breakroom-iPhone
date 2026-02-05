import Foundation

// MARK: - Ticket Status

enum TicketStatus: String, Codable, CaseIterable {
    case open
    case backlog
    case onDeck = "on-deck"
    case inProgress = "in_progress"
    case resolved
    case closed

    var displayName: String {
        switch self {
        case .open: return "Open"
        case .backlog: return "Backlog"
        case .onDeck: return "On Deck"
        case .inProgress: return "In Progress"
        case .resolved: return "Resolved"
        case .closed: return "Closed"
        }
    }

    var isTerminal: Bool {
        self == .resolved || self == .closed
    }

    /// Kanban board columns (excludes legacy 'open')
    static var kanbanStatuses: [TicketStatus] {
        [.backlog, .onDeck, .inProgress, .resolved, .closed]
    }
}

// MARK: - Ticket Priority

enum TicketPriority: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case urgent

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Ticket Model

struct Ticket: Codable, Identifiable {
    let id: Int
    let companyId: Int?
    let creatorId: Int?
    let assignedTo: Int?
    let title: String
    let description: String?
    let status: String?
    let priority: String?
    let createdAt: String?
    let updatedAt: String?
    let resolvedAt: String?

    // Denormalized creator info
    let creatorHandle: String?
    let creatorFirstName: String?
    let creatorLastName: String?

    // Denormalized assignee info
    let assigneeId: Int?
    let assigneeHandle: String?
    let assigneeFirstName: String?
    let assigneeLastName: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, status, priority
        case companyId = "company_id"
        case creatorId = "creator_id"
        case assignedTo = "assigned_to"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case resolvedAt = "resolved_at"
        case creatorHandle = "creator_handle"
        case creatorFirstName = "creator_first_name"
        case creatorLastName = "creator_last_name"
        case assigneeId = "assignee_id"
        case assigneeHandle = "assignee_handle"
        case assigneeFirstName = "assignee_first_name"
        case assigneeLastName = "assignee_last_name"
    }

    var ticketStatus: TicketStatus {
        TicketStatus(rawValue: status ?? "backlog") ?? .backlog
    }

    var ticketPriority: TicketPriority {
        TicketPriority(rawValue: priority ?? "medium") ?? .medium
    }

    var creatorDisplayName: String {
        let parts = [creatorFirstName, creatorLastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? (creatorHandle ?? "Unknown") : parts.joined(separator: " ")
    }

    var assigneeDisplayName: String? {
        guard assigneeId != nil || assigneeHandle != nil else { return nil }
        let parts = [assigneeFirstName, assigneeLastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? assigneeHandle : parts.joined(separator: " ")
    }

    var isResolved: Bool {
        ticketStatus == .resolved || ticketStatus == .closed
    }
}

// MARK: - API Response Types

struct TicketsResponse: Decodable {
    let tickets: [Ticket]
}

struct TicketResponse: Decodable {
    let ticket: Ticket
}

struct ProjectWithTicketsResponse: Decodable {
    let project: ProjectDetail
    let tickets: [Ticket]
}

struct ProjectDetail: Decodable {
    let id: Int
    let title: String
    let description: String?
    let isDefault: Int?
    let isActive: Int?
    let isPublic: Int?
    let companyId: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case isDefault = "is_default"
        case isActive = "is_active"
        case isPublic = "is_public"
        case companyId = "company_id"
    }

    var isDefaultBool: Bool { (isDefault ?? 0) != 0 }
}

// MARK: - API Request Types

struct CreateTicketRequest: Encodable {
    let title: String
    let description: String?
    let priority: String?
    let assignedTo: Int?

    enum CodingKeys: String, CodingKey {
        case title, description, priority
        case assignedTo = "assigned_to"
    }
}

struct UpdateTicketRequest: Encodable {
    let title: String?
    let description: String?
    let status: String?
    let priority: String?
    let assignedTo: Int?

    enum CodingKeys: String, CodingKey {
        case title, description, status, priority
        case assignedTo = "assigned_to"
    }
}

// MARK: - Help Desk Response

struct HelpDeskCompanyResponse: Decodable {
    let company: HelpDeskCompany
}

struct HelpDeskCompany: Decodable {
    let id: Int
    let name: String
}
