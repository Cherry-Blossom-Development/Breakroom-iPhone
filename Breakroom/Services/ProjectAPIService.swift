import Foundation

enum ProjectAPIService {

    // MARK: - Projects Page

    /// Get all projects the user has access to (cross-company)
    static func getMyProjects() async throws -> [Project] {
        let response: ProjectsResponse = try await APIClient.shared.request(
            "/api/projects/my"
        )
        return response.projects
    }

    /// Get pending project invitations for the user
    static func getMyInvites() async throws -> [ProjectInvite] {
        let response: ProjectInvitesResponse = try await APIClient.shared.request(
            "/api/projects/invites"
        )
        return response.invites
    }

    /// Respond to a project invitation
    static func respondToInvite(projectId: Int, accept: Bool) async throws -> String {
        let action = accept ? "accept" : "decline"
        let response: ProjectMessageResponse = try await APIClient.shared.request(
            "/api/projects/\(projectId)/invite/\(action)",
            method: "POST"
        )
        return response.message ?? ""
    }

    // MARK: - Project Board

    /// Get a project with all its tickets, dependencies, assignees, and access flags
    static func getProjectWithTickets(projectId: Int) async throws -> ProjectWithTicketsResponse {
        try await APIClient.shared.request("/api/projects/\(projectId)")
    }

    /// Create a ticket in a specific project
    static func createProjectTicket(
        projectId: Int,
        title: String,
        description: String?,
        priority: String,
        estimateAmount: Double? = nil,
        estimateUnit: String? = nil
    ) async throws -> Ticket {
        let body = CreateProjectTicketRequest(
            title: title,
            description: description,
            priority: priority,
            estimateAmount: estimateAmount,
            estimateUnit: estimateUnit
        )
        let response: TicketResponse = try await APIClient.shared.request(
            "/api/projects/\(projectId)/tickets",
            method: "POST",
            body: body
        )
        return response.ticket
    }

    /// Update ticket fields. A nil value clears the field (unassign, remove estimate).
    static func updateTicketFields(ticketId: Int, fields: [String: Any?]) async throws -> Ticket {
        let response: TicketResponse = try await APIClient.shared.request(
            "/api/helpdesk/ticket/\(ticketId)",
            method: "PUT",
            jsonBody: fields
        )
        return response.ticket
    }

    // MARK: - Dependencies

    /// Add a dependency: ticketId can't be finished until dependsOnId is
    static func addDependency(ticketId: Int, dependsOnId: Int) async throws -> [TicketDependency] {
        let body = AddTicketDependencyRequest(dependsOnTicketId: dependsOnId)
        let response: TicketDependenciesResponse = try await APIClient.shared.request(
            "/api/helpdesk/ticket/\(ticketId)/dependencies",
            method: "POST",
            body: body
        )
        return response.dependencies
    }

    /// Remove a dependency
    static func removeDependency(ticketId: Int, dependsOnId: Int) async throws -> [TicketDependency] {
        let response: TicketDependenciesResponse = try await APIClient.shared.request(
            "/api/helpdesk/ticket/\(ticketId)/dependencies/\(dependsOnId)",
            method: "DELETE"
        )
        return response.dependencies
    }

    // MARK: - Burndown

    /// Get burndown data for a project
    static func getBurndown(projectId: Int) async throws -> BurndownResponse {
        try await APIClient.shared.request("/api/projects/\(projectId)/burndown")
    }

    // MARK: - Settings & Members

    /// Get project settings and members
    static func getSettings(projectId: Int) async throws -> ProjectSettingsResponse {
        try await APIClient.shared.request("/api/projects/\(projectId)/settings")
    }

    /// Update sprint duration
    static func updateSprintDuration(projectId: Int, days: Int) async throws -> ProjectSettings {
        let body = UpdateProjectSettingsRequest(sprintDurationDays: days)
        let response: UpdateProjectSettingsResponse = try await APIClient.shared.request(
            "/api/projects/\(projectId)/settings",
            method: "PUT",
            body: body
        )
        return response.settings
    }

    /// Invite a member to the project
    static func inviteMember(projectId: Int, identifier: String, role: String) async throws -> ProjectMembersResponse {
        let body = InviteProjectMemberRequest(identifier: identifier, role: role)
        return try await APIClient.shared.request(
            "/api/projects/\(projectId)/members",
            method: "POST",
            body: body
        )
    }

    /// Change a member's role
    static func changeMemberRole(projectId: Int, userId: Int, role: String) async throws -> [ProjectMember] {
        let body = UpdateProjectMemberRequest(role: role)
        let response: ProjectMembersResponse = try await APIClient.shared.request(
            "/api/projects/\(projectId)/members/\(userId)",
            method: "PUT",
            body: body
        )
        return response.members
    }

    /// Remove a member from the project
    static func removeMember(projectId: Int, userId: Int) async throws -> [ProjectMember] {
        let response: ProjectMembersResponse = try await APIClient.shared.request(
            "/api/projects/\(projectId)/members/\(userId)",
            method: "DELETE"
        )
        return response.members
    }

    // MARK: - Attachments

    /// Get attachments for a ticket
    static func getAttachments(ticketId: Int) async throws -> [TicketAttachment] {
        let response: TicketAttachmentsResponse = try await APIClient.shared.request(
            "/api/helpdesk/ticket/\(ticketId)/attachments"
        )
        return response.attachments
    }

    /// Upload attachments to a ticket
    static func uploadAttachments(ticketId: Int, files: [(data: Data, fileName: String, mimeType: String)]) async throws -> [TicketAttachment] {
        let response: TicketAttachmentsResponse = try await APIClient.shared.uploadMultipart(
            "/api/helpdesk/ticket/\(ticketId)/attachments",
            files: files.map { (fieldName: "files", data: $0.data, fileName: $0.fileName, mimeType: $0.mimeType) }
        )
        return response.attachments
    }

    /// Delete an attachment
    static func deleteAttachment(attachmentId: Int) async throws -> [TicketAttachment] {
        let response: TicketAttachmentsResponse = try await APIClient.shared.request(
            "/api/helpdesk/attachments/\(attachmentId)",
            method: "DELETE"
        )
        return response.attachments
    }

    /// Download an attachment (returns the file data)
    static func downloadAttachment(attachmentId: Int) async throws -> Data {
        try await APIClient.shared.downloadData("/api/helpdesk/attachments/\(attachmentId)/download")
    }
}
