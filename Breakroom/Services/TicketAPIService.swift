import Foundation

enum TicketAPIService {
    // MARK: - Help Desk (Default Project)

    /// Get tickets for the company's default Help Desk project
    static func getHelpDeskTickets(companyId: Int) async throws -> [Ticket] {
        let response: TicketsResponse = try await APIClient.shared.request(
            "/api/helpdesk/tickets/\(companyId)"
        )
        return response.tickets
    }

    /// Get a single ticket by ID
    static func getTicket(id: Int) async throws -> Ticket {
        let response: TicketResponse = try await APIClient.shared.request(
            "/api/helpdesk/ticket/\(id)"
        )
        return response.ticket
    }

    /// Create a new ticket in the Help Desk
    static func createHelpDeskTicket(
        companyId: Int,
        title: String,
        description: String?,
        priority: String?,
        assignedTo: Int?
    ) async throws -> Ticket {
        let body = CreateTicketRequest(
            title: title,
            description: description,
            priority: priority,
            assignedTo: assignedTo
        )
        let response: TicketResponse = try await APIClient.shared.request(
            "/api/helpdesk/tickets",
            method: "POST",
            body: HelpDeskCreateRequest(companyId: companyId, request: body)
        )
        return response.ticket
    }

    /// Update a ticket
    static func updateTicket(
        id: Int,
        title: String?,
        description: String?,
        status: String?,
        priority: String?,
        assignedTo: Int?
    ) async throws -> Ticket {
        let body = UpdateTicketRequest(
            title: title,
            description: description,
            status: status,
            priority: priority,
            assignedTo: assignedTo
        )
        let response: TicketResponse = try await APIClient.shared.request(
            "/api/helpdesk/ticket/\(id)",
            method: "PUT",
            body: body
        )
        return response.ticket
    }

    // MARK: - Project (Kanban Board)

    /// Get a project with all its tickets
    static func getProjectWithTickets(projectId: Int) async throws -> ProjectWithTicketsResponse {
        try await APIClient.shared.request("/api/projects/\(projectId)")
    }

    /// Create a ticket in a specific project (Kanban)
    static func createProjectTicket(
        projectId: Int,
        title: String,
        description: String?,
        priority: String?,
        assignedTo: Int?
    ) async throws -> Ticket {
        let body = CreateTicketRequest(
            title: title,
            description: description,
            priority: priority,
            assignedTo: assignedTo
        )
        let response: TicketResponse = try await APIClient.shared.request(
            "/api/projects/\(projectId)/tickets",
            method: "POST",
            body: body
        )
        return response.ticket
    }

    /// Update ticket status (for Kanban drag-and-drop)
    static func updateTicketStatus(id: Int, status: String) async throws -> Ticket {
        try await updateTicket(
            id: id,
            title: nil,
            description: nil,
            status: status,
            priority: nil,
            assignedTo: nil
        )
    }

    // MARK: - Ticket Comments

    /// Get all comments for a ticket
    static func getComments(ticketId: Int) async throws -> [TicketComment] {
        let response: TicketCommentsResponse = try await APIClient.shared.request(
            "/api/helpdesk/ticket/\(ticketId)/comments"
        )
        return response.comments
    }

    /// Add a comment to a ticket
    static func addComment(ticketId: Int, content: String) async throws -> TicketComment {
        let response: TicketCommentResponse = try await APIClient.shared.request(
            "/api/helpdesk/ticket/\(ticketId)/comments",
            method: "POST",
            body: ["content": content]
        )
        return response.comment
    }

    /// Edit own comment
    static func editComment(commentId: Int, content: String) async throws -> TicketComment {
        let response: TicketCommentResponse = try await APIClient.shared.request(
            "/api/helpdesk/comment/\(commentId)",
            method: "PUT",
            body: ["content": content]
        )
        return response.comment
    }

    /// Delete own comment (soft delete)
    static func deleteComment(commentId: Int) async throws {
        let _: MessageResponse = try await APIClient.shared.request(
            "/api/helpdesk/comment/\(commentId)",
            method: "DELETE"
        )
    }
}

// MARK: - Helper Request Type

private struct HelpDeskCreateRequest: Encodable {
    let companyId: Int
    let title: String
    let description: String?
    let priority: String?
    let assignedTo: Int?

    enum CodingKeys: String, CodingKey {
        case title, description, priority
        case companyId = "company_id"
        case assignedTo = "assigned_to"
    }

    init(companyId: Int, request: CreateTicketRequest) {
        self.companyId = companyId
        self.title = request.title
        self.description = request.description
        self.priority = request.priority
        self.assignedTo = request.assignedTo
    }
}
