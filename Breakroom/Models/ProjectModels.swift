import Foundation

// MARK: - Estimate Units

/// Utilities for ticket time estimates (hours, days, weeks, months)
enum EstimateUnits {
    static let all = ["hours", "days", "weeks", "months"]

    /// Same limit as backend/utilities/ticketEstimates.js
    static let maxAmount: Double = 9999.99

    /// Error for an entered amount, or nil if valid (blank = no estimate)
    static func validate(amountText: String) -> String? {
        let trimmed = amountText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        guard let amount = Double(trimmed), amount > 0, amount <= maxAmount else {
            return "Estimate must be a number greater than 0 and at most \(formatAmount(maxAmount))"
        }
        return nil
    }

    static func singular(_ unit: String) -> String {
        switch unit {
        case "hours": return "hour"
        case "days": return "day"
        case "weeks": return "week"
        case "months": return "month"
        default: return unit
        }
    }

    static func short(_ unit: String) -> String {
        switch unit {
        case "hours": return "h"
        case "days": return "d"
        case "weeks": return "w"
        case "months": return "mo"
        default: return ""
        }
    }

    /// 3.0 -> "3", 0.5 -> "0.5", 1.25 -> "1.25"
    static func formatAmount(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(amount))
        }
        return String(amount)
    }
}

// MARK: - Project Invites

struct ProjectInvite: Codable, Identifiable {
    let projectId: Int
    let role: String
    let invitedAt: String?
    let projectTitle: String
    let companyName: String?
    let inviterHandle: String?
    let inviterFirstName: String?
    let inviterLastName: String?

    var id: Int { projectId }

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case role
        case invitedAt = "invited_at"
        case projectTitle = "project_title"
        case companyName = "company_name"
        case inviterHandle = "inviter_handle"
        case inviterFirstName = "inviter_first_name"
        case inviterLastName = "inviter_last_name"
    }

    var inviterName: String? {
        let fullName = "\(inviterFirstName ?? "") \(inviterLastName ?? "")".trimmingCharacters(in: .whitespaces)
        if !fullName.isEmpty { return fullName }
        if let handle = inviterHandle { return "@\(handle)" }
        return nil
    }
}

struct ProjectInvitesResponse: Decodable {
    let invites: [ProjectInvite]
}

// MARK: - Ticket Dependencies

/// "ticket_id can't be finished until depends_on_ticket_id is"
struct TicketDependency: Codable, Identifiable, Equatable {
    let ticketId: Int
    let dependsOnTicketId: Int
    let ticketTitle: String?
    let ticketStatus: String?
    let dependsOnTitle: String?
    let dependsOnStatus: String?

    var id: String { "\(ticketId)-\(dependsOnTicketId)" }

    enum CodingKeys: String, CodingKey {
        case ticketId = "ticket_id"
        case dependsOnTicketId = "depends_on_ticket_id"
        case ticketTitle = "ticket_title"
        case ticketStatus = "ticket_status"
        case dependsOnTitle = "depends_on_title"
        case dependsOnStatus = "depends_on_status"
    }

    var isSatisfied: Bool {
        dependsOnStatus == "resolved" || dependsOnStatus == "closed"
    }
}

struct TicketDependenciesResponse: Decodable {
    let dependencies: [TicketDependency]
}

// MARK: - Ticket Timeline (for Burndown/GANTT)

/// First move to in_progress / last move to resolved or closed
struct TicketTimelineEntry: Codable {
    let ticketId: Int
    let startedAt: String?
    let doneAt: String?

    enum CodingKeys: String, CodingKey {
        case ticketId = "ticket_id"
        case startedAt = "started_at"
        case doneAt = "done_at"
    }
}

// MARK: - Project Assignees

struct ProjectAssignee: Codable, Identifiable {
    let userId: Int
    let handle: String?
    let firstName: String?
    let lastName: String?

    var id: Int { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case handle
        case firstName = "first_name"
        case lastName = "last_name"
    }

    var displayName: String {
        let fullName = "\(firstName ?? "") \(lastName ?? "")".trimmingCharacters(in: .whitespaces)
        return fullName.isEmpty ? (handle ?? "Unknown") : fullName
    }
}

// MARK: - Project Settings & Members

enum ProjectRoles {
    static let all = ["owner", "manager", "member", "viewer"]
}

struct ProjectSettings: Codable {
    let sprintDurationDays: Int

    enum CodingKeys: String, CodingKey {
        case sprintDurationDays = "sprint_duration_days"
    }

    init(sprintDurationDays: Int = 14) {
        self.sprintDurationDays = sprintDurationDays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sprintDurationDays = try container.decodeIfPresent(Int.self, forKey: .sprintDurationDays) ?? 14
    }
}

struct ProjectMember: Codable, Identifiable {
    let userId: Int
    let role: String
    let status: String  // active, invited
    let invitedAt: String?
    let joinedAt: String?
    let handle: String?
    let firstName: String?
    let lastName: String?
    let photoPath: String?
    let inviterHandle: String?
    let isEmployee: Bool

    var id: Int { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role, status
        case invitedAt = "invited_at"
        case joinedAt = "joined_at"
        case handle
        case firstName = "first_name"
        case lastName = "last_name"
        case photoPath = "photo_path"
        case inviterHandle = "inviter_handle"
        case isEmployee = "is_employee"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(Int.self, forKey: .userId)
        role = try container.decode(String.self, forKey: .role)
        status = try container.decode(String.self, forKey: .status)
        invitedAt = try container.decodeIfPresent(String.self, forKey: .invitedAt)
        joinedAt = try container.decodeIfPresent(String.self, forKey: .joinedAt)
        handle = try container.decodeIfPresent(String.self, forKey: .handle)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        photoPath = try container.decodeIfPresent(String.self, forKey: .photoPath)
        inviterHandle = try container.decodeIfPresent(String.self, forKey: .inviterHandle)
        isEmployee = try container.decodeIfPresent(Bool.self, forKey: .isEmployee) ?? false
    }

    var displayName: String {
        let fullName = "\(firstName ?? "") \(lastName ?? "")".trimmingCharacters(in: .whitespaces)
        return fullName.isEmpty ? (handle ?? "Unknown") : fullName
    }

    var isInvited: Bool { status == "invited" }
}

struct ProjectSettingsResponse: Decodable {
    let settings: ProjectSettings
    let sprintDurations: [Int]?
    let members: [ProjectMember]
    let roles: [String]?
    let currentUserId: Int?
    let canManage: Bool
    let canManageOwners: Bool

    enum CodingKeys: String, CodingKey {
        case settings, members, roles
        case sprintDurations = "sprint_durations"
        case currentUserId = "current_user_id"
        case canManage = "can_manage"
        case canManageOwners = "can_manage_owners"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        settings = try container.decode(ProjectSettings.self, forKey: .settings)
        sprintDurations = try container.decodeIfPresent([Int].self, forKey: .sprintDurations)
        members = try container.decode([ProjectMember].self, forKey: .members)
        roles = try container.decodeIfPresent([String].self, forKey: .roles)
        currentUserId = try container.decodeIfPresent(Int.self, forKey: .currentUserId)
        canManage = try container.decodeIfPresent(Bool.self, forKey: .canManage) ?? false
        canManageOwners = try container.decodeIfPresent(Bool.self, forKey: .canManageOwners) ?? false
    }
}

struct ProjectMembersResponse: Decodable {
    let message: String?
    let members: [ProjectMember]
}

// MARK: - Burndown Data

struct BurndownProject: Codable {
    let id: Int
    let title: String
    let sprintDurationDays: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case sprintDurationDays = "sprint_duration_days"
        case createdAt = "created_at"
    }
}

struct BurndownTicket: Codable, Identifiable {
    let id: Int
    let title: String
    let status: String
    let estimateAmount: String?
    let estimateUnit: String?
    let createdAt: String?
    let updatedAt: String?
    let resolvedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, status
        case estimateAmount = "estimate_amount"
        case estimateUnit = "estimate_unit"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case resolvedAt = "resolved_at"
    }
}

struct TicketStatusChange: Codable {
    let ticketId: Int
    let fromStatus: String?
    let toStatus: String
    let changedAt: String

    enum CodingKeys: String, CodingKey {
        case ticketId = "ticket_id"
        case fromStatus = "from_status"
        case toStatus = "to_status"
        case changedAt = "changed_at"
    }
}

struct BurndownResponse: Decodable {
    let project: BurndownProject
    let tickets: [BurndownTicket]
    let history: [TicketStatusChange]
}

// MARK: - Ticket Attachments

struct TicketAttachment: Codable, Identifiable {
    let id: Int
    let ticketId: Int
    let fileName: String
    let contentType: String
    let sizeBytes: Int64
    let createdAt: String?
    let uploadedBy: Int?
    let uploaderHandle: String?
    let isImage: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case ticketId = "ticket_id"
        case fileName = "file_name"
        case contentType = "content_type"
        case sizeBytes = "size_bytes"
        case createdAt = "created_at"
        case uploadedBy = "uploaded_by"
        case uploaderHandle = "uploader_handle"
        case isImage = "is_image"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        ticketId = try container.decode(Int.self, forKey: .ticketId)
        fileName = try container.decode(String.self, forKey: .fileName)
        contentType = try container.decode(String.self, forKey: .contentType)
        sizeBytes = try container.decode(Int64.self, forKey: .sizeBytes)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        uploadedBy = try container.decodeIfPresent(Int.self, forKey: .uploadedBy)
        uploaderHandle = try container.decodeIfPresent(String.self, forKey: .uploaderHandle)
        isImage = try container.decodeIfPresent(Bool.self, forKey: .isImage) ?? false
    }

    var formattedSize: String {
        let kb = Double(sizeBytes) / 1024
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        }
        let mb = kb / 1024
        return String(format: "%.1f MB", mb)
    }
}

struct TicketAttachmentsResponse: Decodable {
    let attachments: [TicketAttachment]
}

// MARK: - Project List (extends existing Project model)

struct Project: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String?
    let companyId: Int
    let companyName: String?
    let isDefault: Int
    let isActive: Int
    let isPublic: Int
    let ticketCount: Int
    let sprintDurationDays: Int?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case companyId = "company_id"
        case companyName = "company_name"
        case isDefault = "is_default"
        case isActive = "is_active"
        case isPublic = "is_public"
        case ticketCount = "ticket_count"
        case sprintDurationDays = "sprint_duration_days"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        companyId = try container.decodeIfPresent(Int.self, forKey: .companyId) ?? 0
        companyName = try container.decodeIfPresent(String.self, forKey: .companyName)
        isDefault = try container.decodeIfPresent(Int.self, forKey: .isDefault) ?? 0
        isActive = try container.decodeIfPresent(Int.self, forKey: .isActive) ?? 1
        isPublic = try container.decodeIfPresent(Int.self, forKey: .isPublic) ?? 0
        ticketCount = try container.decodeIfPresent(Int.self, forKey: .ticketCount) ?? 0
        sprintDurationDays = try container.decodeIfPresent(Int.self, forKey: .sprintDurationDays)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    var isDefaultBool: Bool { isDefault != 0 }
    var isActiveBool: Bool { isActive != 0 }
    var isPublicBool: Bool { isPublic != 0 }

    var ticketCountText: String {
        ticketCount == 1 ? "1 ticket" : "\(ticketCount) tickets"
    }
}

struct ProjectsResponse: Decodable {
    let projects: [Project]
}

// MARK: - Extended Project With Tickets Response

struct ExtendedProjectWithTicketsResponse: Decodable {
    let project: Project
    let tickets: [Ticket]
    let dependencies: [TicketDependency]?
    let timeline: [TicketTimelineEntry]?
    let assignees: [ProjectAssignee]?
    let isEmployee: Bool?
    let memberRole: String?
    let canWork: Bool?
    let canManage: Bool?

    enum CodingKeys: String, CodingKey {
        case project, tickets, dependencies, timeline, assignees
        case isEmployee = "is_employee"
        case memberRole = "member_role"
        case canWork = "can_work"
        case canManage = "can_manage"
    }

    var canWorkBool: Bool { canWork ?? (isEmployee ?? false) }
    var canManageBool: Bool { canManage ?? false }
}

// MARK: - API Request Types

struct UpdateProjectSettingsRequest: Encodable {
    let sprintDurationDays: Int

    enum CodingKeys: String, CodingKey {
        case sprintDurationDays = "sprint_duration_days"
    }
}

struct InviteProjectMemberRequest: Encodable {
    let identifier: String  // handle or email
    let role: String
}

struct UpdateProjectMemberRequest: Encodable {
    let role: String
}

struct AddTicketDependencyRequest: Encodable {
    let dependsOnTicketId: Int

    enum CodingKeys: String, CodingKey {
        case dependsOnTicketId = "depends_on_ticket_id"
    }
}

struct CreateProjectTicketRequest: Encodable {
    let title: String
    let description: String?
    let priority: String
    let estimateAmount: Double?
    let estimateUnit: String?

    enum CodingKeys: String, CodingKey {
        case title, description, priority
        case estimateAmount = "estimate_amount"
        case estimateUnit = "estimate_unit"
    }
}

// MARK: - Message Response

struct ProjectMessageResponse: Decodable {
    let message: String?
}

struct UpdateProjectSettingsResponse: Decodable {
    let settings: ProjectSettings
}
