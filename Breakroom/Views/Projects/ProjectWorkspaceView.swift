import SwiftUI
import UIKit

/// Project-level workspace with its own navigation menu.
/// Contains Kanban Board, Gantt Chart, Burndown Chart, and Settings sections.
/// Mirrors Android's ProjectWorkspaceScreen and web's ProjectWorkspacePage.vue.
struct ProjectWorkspaceView: View {
    let projectId: Int

    @Environment(\.dismiss) private var dismiss
    @State private var currentSection: ProjectSection = .kanban
    @State private var showMenu = false

    // Project data (loaded once for the workspace)
    @State private var project: ProjectDetail?
    @State private var isLoading = true
    @State private var loadError: String?

    // Kanban data
    @State private var tickets: [Ticket] = []
    @State private var splitParents: [Ticket] = []  // Tickets split into subtasks
    @State private var dependencies: [TicketDependency] = []
    @State private var timeline: [TicketTimelineEntry] = []
    @State private var assignees: [ProjectAssignee] = []
    @State private var canWork = false
    @State private var canManage = false

    // Unsaved changes tracking (for Kanban board)
    @State private var hasUnsavedChanges = false
    @State private var showUnsavedChangesAlert = false
    @State private var pendingDismiss = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading project...")
            } else if let error = loadError {
                errorView(error)
            } else if let project = project {
                workspaceContent(project: project)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if hasUnsavedChanges {
                        showUnsavedChangesAlert = true
                        pendingDismiss = true
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(project?.title ?? "Project")
                        .font(.headline)
                    if let project = project {
                        Text(currentSection.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(ProjectSection.allCases.filter { $0 != .settings }, id: \.self) { section in
                        Button {
                            currentSection = section
                        } label: {
                            Label(section.label, systemImage: section.icon)
                        }
                    }

                    Divider()

                    Button {
                        currentSection = .settings
                    } label: {
                        Label(ProjectSection.settings.label, systemImage: ProjectSection.settings.icon)
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                }
                .disabled(project == nil)
            }
        }
        .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
            Button("Discard", role: .destructive) {
                hasUnsavedChanges = false
                if pendingDismiss {
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDismiss = false
            }
        } message: {
            Text("You have unsaved changes. Do you want to discard them?")
        }
        .task {
            await loadProject()
        }
    }

    // MARK: - Section Content

    @ViewBuilder
    private func workspaceContent(project: ProjectDetail) -> some View {
        switch currentSection {
        case .kanban:
            ProjectKanbanView(
                projectId: projectId,
                project: project,
                tickets: $tickets,
                splitParents: splitParents,
                dependencies: $dependencies,
                assignees: assignees,
                canWork: canWork,
                canManage: canManage,
                hasUnsavedChanges: $hasUnsavedChanges,
                onBacklog: { currentSection = .backlog },
                onRefresh: { await loadProject() }
            )
        case .backlog:
            ProjectBacklogView(
                projectId: projectId,
                tickets: $tickets,
                splitParents: splitParents,
                assignees: assignees,
                canWork: canWork,
                onRefresh: { await loadProject() }
            )
        case .gantt:
            ProjectGanttView(
                projectId: projectId,
                tickets: tickets,
                dependencies: dependencies,
                timeline: timeline
            )
        case .burndown:
            ProjectBurndownView(projectId: projectId)
        case .settings:
            ProjectSettingsView(projectId: projectId)
        }
    }

    private func placeholderView(title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "hammer.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.bold())
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Button("Go Back") {
                dismiss()
            }
        }
    }

    // MARK: - Data Loading

    private func loadProject() async {
        isLoading = true
        loadError = nil

        do {
            let response = try await ProjectAPIService.getProjectWithTickets(projectId: projectId)
            project = response.project
            tickets = response.tickets
            splitParents = response.splitParents ?? []
            dependencies = response.dependencies ?? []
            timeline = response.timeline ?? []
            assignees = response.assignees ?? []
            canWork = response.canWorkBool
            canManage = response.canManageBool
        } catch let error as APIError {
            loadError = error.localizedDescription
        } catch {
            loadError = "Failed to load project"
        }

        isLoading = false
    }
}

// MARK: - Project Section Enum

enum ProjectSection: String, CaseIterable {
    case kanban
    case backlog
    case gantt
    case burndown
    case settings

    var label: String {
        switch self {
        case .kanban: return "Kanban Board"
        case .backlog: return "Backlog"
        case .gantt: return "GANTT Chart"
        case .burndown: return "Burndown Chart"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .kanban: return "rectangle.split.3x1"
        case .backlog: return "list.bullet"
        case .gantt: return "calendar.day.timeline.left"
        case .burndown: return "chart.line.downtrend.xyaxis"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Project Kanban View (embedded in workspace)

/// The Kanban board content for a project workspace.
/// This is a wrapper that uses the existing KanbanBoardView logic.
struct ProjectKanbanView: View {
    let projectId: Int
    let project: ProjectDetail
    @Binding var tickets: [Ticket]
    let splitParents: [Ticket]
    @Binding var dependencies: [TicketDependency]
    let assignees: [ProjectAssignee]
    let canWork: Bool
    let canManage: Bool
    @Binding var hasUnsavedChanges: Bool
    let onBacklog: () -> Void
    let onRefresh: () async -> Void

    @State private var selectedTicket: Ticket?
    @State private var showCreateTicket = false
    @State private var showClosedTickets = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                if canWork {
                    Button {
                        showCreateTicket = true
                    } label: {
                        Label("New Ticket", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Spacer()

                Button {
                    onBacklog()
                } label: {
                    let backlogCount = tickets.filter { $0.ticketStatus == .backlog && !$0.isSplit }.count
                    Label("Backlog (\(backlogCount))", systemImage: "list.bullet")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    showClosedTickets = true
                } label: {
                    Label("Closed", systemImage: "checkmark.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Kanban columns
            kanbanBoard
        }
        .sheet(isPresented: $showCreateTicket) {
            CreateProjectTicketView(projectId: projectId, assignees: assignees) { newTicket in
                tickets.append(newTicket)
            }
        }
        .sheet(isPresented: $showClosedTickets) {
            ClosedTicketsView(tickets: tickets.filter { $0.isResolved })
        }
        .sheet(item: $selectedTicket) { ticket in
            TicketDetailView(
                ticket: ticket,
                assignees: assignees,
                dependencies: dependencies.filter { $0.ticketId == ticket.id },
                allTickets: tickets,
                canWork: canWork,
                canManage: canManage,
                onUpdate: { updatedTicket in
                    if let index = tickets.firstIndex(where: { $0.id == updatedTicket.id }) {
                        tickets[index] = updatedTicket
                    }
                },
                onSplit: {
                    Task { await onRefresh() }
                }
            )
        }
        .refreshable {
            await onRefresh()
        }
    }

    private var kanbanBoard: some View {
        // Kanban shows On Deck and In Progress only; Backlog is a separate view
        // Filter out split parents (they're shown in backlog with their subtasks)
        let activeTickets = tickets.filter { !$0.isResolved && !$0.isSplit }
        let columns: [(status: TicketStatus, tickets: [Ticket])] = [
            (.onDeck, activeTickets.filter { $0.ticketStatus == .onDeck }),
            (.inProgress, activeTickets.filter { $0.ticketStatus == .inProgress })
        ]

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(columns, id: \.status) { column in
                    kanbanColumn(status: column.status, tickets: column.tickets)
                }
            }
            .padding()
        }
    }

    private func kanbanColumn(status: TicketStatus, tickets: [Ticket]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(status.displayName)
                    .font(.headline)
                Text("(\(tickets.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)

            // Cards
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(tickets) { ticket in
                        ticketCard(ticket)
                            .onTapGesture {
                                selectedTicket = ticket
                            }
                    }
                }
            }
        }
        .frame(width: 280)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func ticketCard(_ ticket: Ticket) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ticket.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)

            HStack(spacing: 4) {
                // Priority badge
                Text(ticket.ticketPriority.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ticket.ticketPriority.color.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                // Estimate badge
                if ticket.hasEstimate {
                    Text(ticket.shortEstimate)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Spacer()

                // Assignee
                if let assignee = ticket.assigneeDisplayName {
                    Text(assignee)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Create Project Ticket View

struct CreateProjectTicketView: View {
    let projectId: Int
    let assignees: [ProjectAssignee]
    let onCreated: (Ticket) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var priority = "medium"
    @State private var estimateAmount = ""
    @State private var estimateUnit = "hours"
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(["low", "medium", "high", "urgent"], id: \.self) { p in
                            Text(p.capitalized).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Estimate (optional)") {
                    HStack {
                        TextField("Amount", text: $estimateAmount)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)

                        Picker("Unit", selection: $estimateUnit) {
                            ForEach(EstimateUnits.all, id: \.self) { unit in
                                Text(unit.capitalized).tag(unit)
                            }
                        }
                    }

                    if let validationError = EstimateUnits.validate(amountText: estimateAmount) {
                        Text(validationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if let error = error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createTicket() }
                    }
                    .disabled(title.isEmpty || isCreating || EstimateUnits.validate(amountText: estimateAmount) != nil)
                }
            }
        }
    }

    private func createTicket() async {
        isCreating = true
        error = nil

        let amount = estimateAmount.isEmpty ? nil : Double(estimateAmount)
        let unit = amount != nil ? estimateUnit : nil

        do {
            let ticket = try await ProjectAPIService.createProjectTicket(
                projectId: projectId,
                title: title,
                description: description.isEmpty ? nil : description,
                priority: priority,
                estimateAmount: amount,
                estimateUnit: unit
            )
            onCreated(ticket)
            dismiss()
        } catch let error as APIError {
            self.error = error.localizedDescription
        } catch {
            self.error = "Failed to create ticket"
        }

        isCreating = false
    }
}

// MARK: - Closed Tickets View

struct ClosedTicketsView: View {
    let tickets: [Ticket]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if tickets.isEmpty {
                    ContentUnavailableView {
                        Label("No Closed Tickets", systemImage: "checkmark.circle")
                    } description: {
                        Text("Resolved and closed tickets will appear here.")
                    }
                } else {
                    List(tickets) { ticket in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ticket.title)
                                .font(.body)
                            HStack {
                                Text(ticket.ticketStatus.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let resolvedAt = ticket.resolvedAt {
                                    Text("·")
                                        .foregroundStyle(.secondary)
                                    Text(resolvedAt)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Closed Tickets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Ticket Detail View (Editable with Staged Changes)

struct TicketDetailView: View {
    let ticket: Ticket
    let assignees: [ProjectAssignee]
    let dependencies: [TicketDependency]
    let allTickets: [Ticket]
    let canWork: Bool
    let canManage: Bool
    let onUpdate: (Ticket) -> Void
    var onSplit: (() -> Void)? = nil  // Called when ticket is split, to trigger refresh

    @Environment(\.dismiss) private var dismiss

    // Staged edits - local state until Save is clicked
    @State private var editedTitle: String
    @State private var editedDescription: String
    @State private var editedStatus: TicketStatus
    @State private var editedPriority: TicketPriority
    @State private var editedAssigneeId: Int?
    @State private var editedEstimateAmount: String
    @State private var editedEstimateUnit: String

    // Staged dependency changes
    @State private var addedDependencyIds: Set<Int> = []
    @State private var removedDependencyIds: Set<Int> = []

    // Attachments state
    @State private var attachments: [TicketAttachment] = []
    @State private var pendingFiles: [PendingFile] = []
    @State private var pendingRemovals: Set<Int> = []
    @State private var isLoadingAttachments = false
    @State private var attachmentError: String?
    @State private var isOpeningAttachment = false

    // Contributors state (migration 088)
    @State private var contributors: [TicketContributor] = []
    @State private var roleSuggestions: [String] = []
    @State private var isLoadingContributors = false
    @State private var stagedContributors: [StagedContributor] = []  // Staged changes

    // UI state
    @State private var isSaving = false
    @State private var error: String?
    @State private var showUnsavedChangesAlert = false
    @State private var showAddDependency = false
    @State private var showSplitTicket = false

    init(
        ticket: Ticket,
        assignees: [ProjectAssignee],
        dependencies: [TicketDependency],
        allTickets: [Ticket],
        canWork: Bool,
        canManage: Bool,
        onUpdate: @escaping (Ticket) -> Void,
        onSplit: (() -> Void)? = nil
    ) {
        self.ticket = ticket
        self.assignees = assignees
        self.dependencies = dependencies
        self.allTickets = allTickets
        self.canWork = canWork
        self.canManage = canManage
        self.onUpdate = onUpdate
        self.onSplit = onSplit

        // Initialize staged edits from ticket
        _editedTitle = State(initialValue: ticket.title)
        _editedDescription = State(initialValue: ticket.description ?? "")
        _editedStatus = State(initialValue: ticket.ticketStatus)
        _editedPriority = State(initialValue: ticket.ticketPriority)
        _editedAssigneeId = State(initialValue: ticket.assignedTo)
        _editedEstimateAmount = State(initialValue: ticket.estimateAmount ?? "")
        _editedEstimateUnit = State(initialValue: ticket.estimateUnit ?? "hours")
    }

    private var hasUnsavedChanges: Bool {
        editedTitle != ticket.title ||
        editedDescription != (ticket.description ?? "") ||
        editedStatus != ticket.ticketStatus ||
        editedPriority != ticket.ticketPriority ||
        editedAssigneeId != ticket.assignedTo ||
        editedEstimateAmount != (ticket.estimateAmount ?? "") ||
        editedEstimateUnit != (ticket.estimateUnit ?? "hours") ||
        !addedDependencyIds.isEmpty ||
        !removedDependencyIds.isEmpty ||
        !pendingFiles.isEmpty ||
        !pendingRemovals.isEmpty ||
        hasContributorChanges
    }

    private var hasContributorChanges: Bool {
        // Compare stagedContributors to original contributors
        guard contributors.count == stagedContributors.count else { return true }
        for original in contributors {
            if let staged = stagedContributors.first(where: { $0.userId == original.userId }) {
                if staged.role != original.role { return true }
            } else {
                return true  // User was removed
            }
        }
        return false
    }

    /// Current dependencies including staged changes
    private var currentDependencies: [TicketDependency] {
        dependencies.filter { !removedDependencyIds.contains($0.dependsOnTicketId) }
    }

    /// Tickets that can be added as dependencies (not already a dependency, not this ticket)
    private var availableDependencies: [Ticket] {
        let existingIds = Set(dependencies.map { $0.dependsOnTicketId })
        let currentIds = existingIds.union(addedDependencyIds).subtracting(removedDependencyIds)
        return allTickets.filter { $0.id != ticket.id && !currentIds.contains($0.id) }
    }

    private var estimateValidation: String? {
        EstimateUnits.validate(amountText: editedEstimateAmount)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Details section
                Section("Details") {
                    if canWork {
                        TextField("Title *", text: $editedTitle)
                        TextField("Description", text: $editedDescription, axis: .vertical)
                            .lineLimit(3...6)
                    } else {
                        LabeledContent("Title", value: editedTitle)
                        if !editedDescription.isEmpty {
                            LabeledContent("Description", value: editedDescription)
                        }
                    }
                }

                // Status section
                Section("Status") {
                    if canWork {
                        Picker("Status", selection: $editedStatus) {
                            ForEach(TicketStatus.allCases, id: \.self) { s in
                                Text(s.displayName).tag(s)
                            }
                        }
                    } else {
                        LabeledContent("Status", value: editedStatus.displayName)
                    }
                }

                // Priority section
                Section("Priority") {
                    if canWork {
                        Picker("Priority", selection: $editedPriority) {
                            ForEach(TicketPriority.allCases, id: \.self) { p in
                                Text(p.displayName).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        LabeledContent("Priority", value: editedPriority.displayName)
                    }
                }

                // Estimate section
                Section("Estimate") {
                    if canWork {
                        HStack {
                            TextField("Amount", text: $editedEstimateAmount)
                                .keyboardType(.decimalPad)
                                .frame(width: 80)

                            Picker("Unit", selection: $editedEstimateUnit) {
                                ForEach(EstimateUnits.all, id: \.self) { unit in
                                    Text(unit.capitalized).tag(unit)
                                }
                            }
                        }

                        if let validation = estimateValidation {
                            Text(validation)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } else if ticket.hasEstimate {
                        LabeledContent("Time", value: ticket.formattedEstimate)
                    } else {
                        Text("No estimate set")
                            .foregroundStyle(.secondary)
                    }
                }

                // Assignee section
                Section("Assigned To") {
                    if canWork && !assignees.isEmpty {
                        Picker("Assignee", selection: $editedAssigneeId) {
                            Text("Unassigned").tag(nil as Int?)
                            ForEach(assignees) { assignee in
                                Text(assignee.displayName).tag(assignee.userId as Int?)
                            }
                        }
                    } else if let assignee = ticket.assigneeDisplayName {
                        Text(assignee)
                    } else {
                        Text("Unassigned")
                            .foregroundStyle(.secondary)
                    }
                }

                // Dependencies section
                Section {
                    // Existing dependencies (not removed)
                    ForEach(currentDependencies) { dep in
                        HStack {
                            Image(systemName: dep.isSatisfied ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(dep.isSatisfied ? .green : .orange)
                            Text(dep.dependsOnTitle ?? "Ticket #\(dep.dependsOnTicketId)")

                            if canWork {
                                Spacer()
                                Button {
                                    removedDependencyIds.insert(dep.dependsOnTicketId)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Newly added dependencies (from staged changes)
                    ForEach(Array(addedDependencyIds), id: \.self) { ticketId in
                        if let depTicket = allTickets.first(where: { $0.id == ticketId }) {
                            HStack {
                                Image(systemName: "circle")
                                    .foregroundStyle(.orange)
                                Text(depTicket.title)
                                Text("(new)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()
                                Button {
                                    addedDependencyIds.remove(ticketId)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Add dependency button
                    if canWork && !availableDependencies.isEmpty {
                        Button {
                            showAddDependency = true
                        } label: {
                            Label("Add Blocker", systemImage: "plus")
                        }
                    }

                    if currentDependencies.isEmpty && addedDependencyIds.isEmpty && !canWork {
                        Text("No dependencies")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Blocked By")
                }

                // Attachments section
                Section {
                    if isLoadingAttachments {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading attachments...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        TicketAttachmentsSection(
                            attachments: attachments,
                            pendingFiles: $pendingFiles,
                            pendingRemovals: $pendingRemovals,
                            canAttach: canWork,
                            canRemove: { _ in canWork },
                            busy: isSaving || isOpeningAttachment,
                            error: attachmentError,
                            onOpen: { attachment in
                                Task { await openAttachment(attachment) }
                            }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Attachments")
                }

                // Contributors section (migration 088)
                Section {
                    if isLoadingContributors {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Loading contributors...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        contributorsSection
                    }
                } header: {
                    Text("Contributors")
                }

                // Info section
                Section {
                    LabeledContent("Created by", value: ticket.creatorDisplayName)
                    if let createdAt = ticket.createdAt {
                        LabeledContent("Created", value: createdAt)
                    }
                    if ticket.isSubtask, let parentId = ticket.parentTicketId {
                        LabeledContent("Parent ticket", value: "#\(parentId)")
                    }
                }

                // Actions section
                if canWork && !ticket.isResolved {
                    Section {
                        Button {
                            showSplitTicket = true
                        } label: {
                            Label(
                                ticket.isSplit ? "Add Subtasks" : "Split into Subtasks",
                                systemImage: "arrow.branch"
                            )
                        }
                    } header: {
                        Text("Actions")
                    }
                }

                // Error display
                if let error = error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Ticket #\(ticket.id)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showUnsavedChangesAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }

                if canWork {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task { await saveChanges() }
                        } label: {
                            if isSaving {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Save")
                            }
                        }
                        .disabled(!hasUnsavedChanges || isSaving || editedTitle.isEmpty || estimateValidation != nil)
                    }
                }
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Do you want to discard them?")
            }
            .sheet(isPresented: $showAddDependency) {
                AddDependencySheet(
                    availableTickets: availableDependencies,
                    onSelect: { selectedTicket in
                        addedDependencyIds.insert(selectedTicket.id)
                    }
                )
            }
            .sheet(isPresented: $showSplitTicket) {
                SplitTicketSheet(ticket: ticket) {
                    onSplit?()
                    dismiss()
                }
            }
            .task {
                await loadAttachments()
                await loadContributors()
            }
        }
    }

    // MARK: - Contributors Section

    @ViewBuilder
    private var contributorsSection: some View {
        // Current contributors
        ForEach(stagedContributors.indices, id: \.self) { index in
            contributorRow(index: index)
        }

        // Add contributor (only show people not already added)
        if canWork {
            let addedIds = Set(stagedContributors.map { $0.userId })
            let available = assignees.filter { !addedIds.contains($0.userId) && $0.userId != ticket.assignedTo }

            if !available.isEmpty {
                Menu {
                    ForEach(available) { person in
                        Button(person.displayName) {
                            stagedContributors.append(StagedContributor(
                                userId: person.userId,
                                role: "",
                                handle: person.handle,
                                firstName: person.firstName,
                                lastName: person.lastName
                            ))
                        }
                    }
                } label: {
                    Label("Add Contributor", systemImage: "plus")
                }
            }
        }

        if stagedContributors.isEmpty && !canWork {
            Text("No contributors")
                .foregroundStyle(.secondary)
        }
    }

    private func contributorRow(index: Int) -> some View {
        let contributor = stagedContributors[index]

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(contributor.displayName)
                    .font(.subheadline)

                if canWork {
                    TextField("Role (optional)", text: $stagedContributors[index].role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !contributor.role.isEmpty {
                    Text(contributor.role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if canWork {
                Button {
                    stagedContributors.remove(at: index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Data Loading

    private func loadContributors() async {
        isLoadingContributors = true

        do {
            async let contributorsTask = TicketAPIService.getContributors(ticketId: ticket.id)
            async let rolesTask = TicketAPIService.getContributorRoles(ticketId: ticket.id)

            let (loadedContributors, loadedRoles) = try await (contributorsTask, rolesTask)
            contributors = loadedContributors
            roleSuggestions = loadedRoles
            stagedContributors = loadedContributors.map { c in
                StagedContributor(
                    userId: c.userId,
                    role: c.role,
                    handle: c.handle,
                    firstName: c.firstName,
                    lastName: c.lastName
                )
            }
        } catch {
            // Silently fail - contributors are optional
        }

        isLoadingContributors = false
    }

    private func loadAttachments() async {
        isLoadingAttachments = true
        attachmentError = nil

        do {
            attachments = try await ProjectAPIService.getAttachments(ticketId: ticket.id)
        } catch {
            attachmentError = "Failed to load attachments"
        }

        isLoadingAttachments = false
    }

    private func openAttachment(_ attachment: TicketAttachment) async {
        isOpeningAttachment = true
        attachmentError = nil

        do {
            let data = try await ProjectAPIService.downloadAttachment(attachmentId: attachment.id)

            // Save to temp directory
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(attachment.fileName)
            try data.write(to: fileURL)

            // Open with system
            await MainActor.run {
                #if os(iOS)
                // Use UIActivityViewController on iOS
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                    rootVC.present(activityVC, animated: true)
                }
                #endif
            }
        } catch {
            attachmentError = "Failed to open attachment"
        }

        isOpeningAttachment = false
    }

    private func saveChanges() async {
        isSaving = true
        error = nil

        // Build fields dictionary with only changed values
        var fields: [String: Any?] = [:]

        if editedTitle != ticket.title {
            fields["title"] = editedTitle
        }
        if editedDescription != (ticket.description ?? "") {
            fields["description"] = editedDescription.isEmpty ? nil : editedDescription
        }
        if editedStatus != ticket.ticketStatus {
            fields["status"] = editedStatus.rawValue
        }
        if editedPriority != ticket.ticketPriority {
            fields["priority"] = editedPriority.rawValue
        }
        if editedAssigneeId != ticket.assignedTo {
            fields["assigned_to"] = editedAssigneeId
        }

        // Handle estimate
        let newAmount = editedEstimateAmount.isEmpty ? nil : Double(editedEstimateAmount)
        let oldAmount = ticket.estimateAmountDouble
        if newAmount != oldAmount || editedEstimateUnit != (ticket.estimateUnit ?? "hours") {
            fields["estimate_amount"] = newAmount
            fields["estimate_unit"] = newAmount != nil ? editedEstimateUnit : nil
        }

        do {
            // Save field changes
            var updated = ticket
            if !fields.isEmpty {
                updated = try await ProjectAPIService.updateTicketFields(ticketId: ticket.id, fields: fields)
            }

            // Save dependency changes
            for dependsOnId in addedDependencyIds {
                _ = try await ProjectAPIService.addDependency(ticketId: ticket.id, dependsOnId: dependsOnId)
            }
            for dependsOnId in removedDependencyIds {
                _ = try await ProjectAPIService.removeDependency(ticketId: ticket.id, dependsOnId: dependsOnId)
            }

            // Upload new attachments
            if !pendingFiles.isEmpty {
                let files = pendingFiles.map { (data: $0.data, fileName: $0.fileName, mimeType: $0.mimeType) }
                _ = try await ProjectAPIService.uploadAttachments(ticketId: ticket.id, files: files)
            }

            // Delete removed attachments
            for attachmentId in pendingRemovals {
                _ = try await ProjectAPIService.deleteAttachment(attachmentId: attachmentId)
            }

            // Save contributors if changed
            if hasContributorChanges {
                let entries = stagedContributors.map { (userId: $0.userId, role: $0.role) }
                _ = try await TicketAPIService.saveContributors(ticketId: ticket.id, contributors: entries)
            }

            onUpdate(updated)
            dismiss()
        } catch let error as APIError {
            self.error = error.localizedDescription
        } catch {
            self.error = "Failed to save changes"
        }

        isSaving = false
    }
}

// MARK: - Add Dependency Sheet

struct AddDependencySheet: View {
    let availableTickets: [Ticket]
    let onSelect: (Ticket) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredTickets: [Ticket] {
        if searchText.isEmpty {
            return availableTickets
        }
        return availableTickets.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if availableTickets.isEmpty {
                    ContentUnavailableView {
                        Label("No Tickets", systemImage: "ticket")
                    } description: {
                        Text("No other tickets available to add as blockers.")
                    }
                } else {
                    List {
                        ForEach(filteredTickets) { ticket in
                            Button {
                                onSelect(ticket)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ticket.title)
                                        .font(.body)
                                    HStack {
                                        Text(ticket.ticketStatus.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("·")
                                            .foregroundStyle(.secondary)
                                        Text(ticket.ticketPriority.displayName)
                                            .font(.caption)
                                            .foregroundStyle(ticket.ticketPriority.color)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search tickets")
                }
            }
            .navigationTitle("Add Blocker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Project Backlog View

/// Backlog list grouped by split parents, with subtasks nested under their parent.
struct ProjectBacklogView: View {
    let projectId: Int
    @Binding var tickets: [Ticket]
    let splitParents: [Ticket]
    let assignees: [ProjectAssignee]
    let canWork: Bool
    let onRefresh: () async -> Void

    @State private var selectedTicket: Ticket?
    @State private var collapsedParents: Set<Int> = []
    @State private var searchText = ""
    @State private var orderedItems: [BacklogItem] = []
    @State private var isSavingOrder = false

    /// Backlog items: tickets in backlog status, excluding split parents (they're shown as group headers)
    private var backlogTickets: [Ticket] {
        tickets.filter { $0.ticketStatus == .backlog && !$0.isSplit }
    }

    /// Build backlog structure: top-level items and grouped subtasks
    private var backlogStructure: [BacklogItem] {
        // Index split parents by ID
        let parentById = Dictionary(uniqueKeysWithValues: splitParents.map { ($0.id, $0) })

        // Group subtasks by their parent
        var subtasksByParent: [Int: [Ticket]] = [:]
        var topLevel: [Ticket] = []

        for ticket in backlogTickets {
            if let parentId = ticket.parentTicketId, parentById[parentId] != nil {
                subtasksByParent[parentId, default: []].append(ticket)
            } else {
                topLevel.append(ticket)
            }
        }

        // Build items
        var items: [BacklogItem] = []

        // Sort top-level by backlog rank, then by ID
        let sortedTop = topLevel.sorted {
            if let r1 = $0.backlogRank, let r2 = $1.backlogRank {
                return r1 < r2
            }
            if $0.backlogRank != nil { return true }
            if $1.backlogRank != nil { return false }
            return $0.id < $1.id
        }

        for ticket in sortedTop {
            if ticket.isSplit {
                // This shouldn't happen since we filter out split tickets, but just in case
                continue
            }

            // Check if this ticket is a split parent with backlog subtasks
            if let parent = parentById[ticket.id], let subtasks = subtasksByParent[ticket.id], !subtasks.isEmpty {
                items.append(.group(parent: parent, children: subtasks.sorted { $0.id < $1.id }))
            } else {
                items.append(.ticket(ticket))
            }
        }

        // Add groups for split parents that have backlog subtasks but aren't in backlog themselves
        for (parentId, subtasks) in subtasksByParent {
            if let parent = parentById[parentId], !backlogTickets.contains(where: { $0.id == parentId }) {
                items.append(.group(parent: parent, children: subtasks.sorted { $0.id < $1.id }))
            }
        }

        return items
    }

    /// Filtered by search
    private var filteredItems: [BacklogItem] {
        guard !searchText.isEmpty else { return backlogStructure }

        return backlogStructure.compactMap { item in
            switch item {
            case .ticket(let ticket):
                if ticket.title.localizedCaseInsensitiveContains(searchText) {
                    return item
                }
                return nil
            case .group(let parent, let children):
                let matchingChildren = children.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
                if parent.title.localizedCaseInsensitiveContains(searchText) || !matchingChildren.isEmpty {
                    return .group(parent: parent, children: matchingChildren.isEmpty ? children : matchingChildren)
                }
                return nil
            }
        }
    }

    /// Items for display (filtered if searching, otherwise ordered)
    private var displayItems: [BacklogItem] {
        guard searchText.isEmpty else { return filteredItems }
        return orderedItems.isEmpty ? backlogStructure : orderedItems
    }

    var body: some View {
        VStack(spacing: 0) {
            // Summary bar with reorder button
            HStack {
                Text("\(backlogTickets.count) ticket\(backlogTickets.count == 1 ? "" : "s") in backlog")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if canWork && !backlogTickets.isEmpty && searchText.isEmpty {
                    if isSavingOrder {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        EditButton()
                            .font(.subheadline)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Backlog list
            if backlogTickets.isEmpty {
                ContentUnavailableView {
                    Label("Backlog Empty", systemImage: "tray")
                } description: {
                    Text("No tickets in the backlog. Move tickets here to plan future work.")
                }
            } else {
                List {
                    ForEach(displayItems) { item in
                        switch item {
                        case .ticket(let ticket):
                            backlogRow(ticket: ticket)
                                .onTapGesture { selectedTicket = ticket }

                        case .group(let parent, let children):
                            backlogGroup(parent: parent, children: children)
                        }
                    }
                    .onMove { source, destination in
                        if canWork && searchText.isEmpty {
                            moveItems(from: source, to: destination)
                        }
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search backlog")
            }
        }
        .onAppear {
            orderedItems = backlogStructure
        }
        .sheet(item: $selectedTicket) { ticket in
            TicketDetailView(
                ticket: ticket,
                assignees: assignees,
                dependencies: [],  // TODO: pass dependencies
                allTickets: tickets,
                canWork: canWork,
                canManage: false,
                onUpdate: { updatedTicket in
                    if let index = tickets.firstIndex(where: { $0.id == updatedTicket.id }) {
                        tickets[index] = updatedTicket
                    }
                },
                onSplit: {
                    Task { await onRefresh() }
                }
            )
        }
        .refreshable {
            await onRefresh()
        }
    }

    private func backlogRow(ticket: Ticket) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("#\(ticket.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ticket.title)
                        .font(.subheadline)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    // Priority
                    Text(ticket.ticketPriority.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ticket.ticketPriority.color.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    // Estimate
                    if ticket.hasEstimate {
                        Text(ticket.shortEstimate)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Assignee
                    if let assignee = ticket.assigneeDisplayName {
                        Text(assignee)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func backlogGroup(parent: Ticket, children: [Ticket]) -> some View {
        let isCollapsed = collapsedParents.contains(parent.id)

        return VStack(alignment: .leading, spacing: 0) {
            // Group header
            HStack {
                Button {
                    withAnimation {
                        if isCollapsed {
                            collapsedParents.remove(parent.id)
                        } else {
                            collapsedParents.insert(parent.id)
                        }
                    }
                } label: {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)

                Text("#\(parent.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(parent.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Spacer()

                Text("\(children.count) subtask\(children.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(parent.splitMode == "category" ? "Category" : "Split")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { selectedTicket = parent }

            // Subtasks (when expanded)
            if !isCollapsed {
                ForEach(children) { child in
                    HStack {
                        Spacer().frame(width: 24)  // Indent
                        backlogRow(ticket: child)
                    }
                    .onTapGesture { selectedTicket = child }
                }
            }
        }
    }

    // MARK: - Drag to Reorder

    private func moveItems(from source: IndexSet, to destination: Int) {
        orderedItems.move(fromOffsets: source, toOffset: destination)
        Task { await saveBacklogOrder() }
    }

    private func saveBacklogOrder() async {
        isSavingOrder = true

        // Build flat list of ticket IDs in display order
        var ticketIds: [Int] = []
        for item in orderedItems {
            switch item {
            case .ticket(let ticket):
                ticketIds.append(ticket.id)
            case .group(let parent, let children):
                ticketIds.append(parent.id)
                ticketIds.append(contentsOf: children.map { $0.id })
            }
        }

        do {
            try await TicketAPIService.saveBacklogOrder(projectId: projectId, order: ticketIds)
        } catch {
            // Silently fail - order will be reset on next refresh
        }

        isSavingOrder = false
    }
}

/// Backlog list item: either a single ticket or a group with parent and children
enum BacklogItem: Identifiable, Equatable {
    case ticket(Ticket)
    case group(parent: Ticket, children: [Ticket])

    var id: String {
        switch self {
        case .ticket(let t): return "ticket-\(t.id)"
        case .group(let p, _): return "group-\(p.id)"
        }
    }

    static func == (lhs: BacklogItem, rhs: BacklogItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Split Ticket Sheet

/// Sheet for splitting a ticket into subtasks (migration 086)
struct SplitTicketSheet: View {
    let ticket: Ticket
    let onSplit: () -> Void

    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var mode: String
    @State private var subtasks: [SubtaskRow]
    @State private var estimatesEdited = false
    @State private var isSplitting = false
    @State private var error: String?

    private let maxSubtasks = 20

    init(ticket: Ticket, onSplit: @escaping () -> Void) {
        self.ticket = ticket
        self.onSplit = onSplit

        // If already split, keep the mode; otherwise default to hidden
        let initialMode = ticket.splitMode ?? "hidden"
        _mode = State(initialValue: initialMode)

        // Start with 2 empty rows (or 1 if already split)
        let unit = ticket.estimateUnit ?? "hours"
        let initialRows = ticket.isSplit
            ? [SubtaskRow(title: "", estimateAmount: "", estimateUnit: unit)]
            : [
                SubtaskRow(title: "", estimateAmount: "", estimateUnit: unit),
                SubtaskRow(title: "", estimateAmount: "", estimateUnit: unit)
              ]
        _subtasks = State(initialValue: initialRows)
    }

    private var hasEstimate: Bool {
        ticket.estimateAmountDouble != nil && ticket.estimateUnit != nil
    }

    private var canAddMore: Bool {
        subtasks.count < maxSubtasks
    }

    private var canRemove: Bool {
        subtasks.count > (ticket.isSplit ? 1 : 2)
    }

    private var isValid: Bool {
        subtasks.allSatisfy { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Mode picker (only for new splits)
                if !ticket.isSplit {
                    Section {
                        Picker("Split mode", selection: $mode) {
                            Text("Hidden (off all views)").tag("hidden")
                            Text("Category (shown on charts)").tag("category")
                        }
                    } header: {
                        Text("Parent Behavior")
                    } footer: {
                        Text(mode == "hidden"
                             ? "The parent ticket will be hidden from the board and charts. Only its subtasks will be visible."
                             : "The parent will appear as a category on the GANTT chart and as a filter on the Burndown chart.")
                    }
                }

                // Subtasks list
                Section {
                    ForEach(Array(subtasks.enumerated()), id: \.offset) { index, _ in
                        subtaskRow(index: index)
                    }
                    .onDelete { indices in
                        subtasks.remove(atOffsets: indices)
                    }

                    if canAddMore {
                        Button {
                            subtasks.append(SubtaskRow(
                                title: "",
                                estimateAmount: "",
                                estimateUnit: ticket.estimateUnit ?? "hours"
                            ))
                        } label: {
                            Label("Add Subtask", systemImage: "plus")
                        }
                    }
                } header: {
                    Text("Subtasks")
                } footer: {
                    if !ticket.isSplit && hasEstimate {
                        Text("Estimates will be divided evenly from the parent's \(ticket.formattedEstimate). Edit any estimate to stop auto-dividing.")
                    }
                }

                // Total estimate (if all same unit)
                if let total = subtaskTotal {
                    Section {
                        LabeledContent("Total estimate", value: total)
                        if hasEstimate {
                            LabeledContent("Parent estimate", value: ticket.formattedEstimate)
                        }
                    }
                }

                // Error
                if let error = error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(ticket.isSplit ? "Add Subtasks" : "Split Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await split() }
                    } label: {
                        if isSplitting {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Split")
                        }
                    }
                    .disabled(!isValid || isSplitting)
                }
            }
            .onAppear {
                if !ticket.isSplit && hasEstimate && !estimatesEdited {
                    divideEstimatesEvenly()
                }
            }
            .onChange(of: subtasks.count) {
                if !ticket.isSplit && hasEstimate && !estimatesEdited {
                    divideEstimatesEvenly()
                }
            }
        }
    }

    private func subtaskRow(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Subtask title", text: $subtasks[index].title)

            HStack {
                TextField("Estimate", text: $subtasks[index].estimateAmount)
                    .keyboardType(.decimalPad)
                    .frame(width: 60)
                    .onChange(of: subtasks[index].estimateAmount) { _, _ in
                        estimatesEdited = true
                    }

                Picker("Unit", selection: $subtasks[index].estimateUnit) {
                    ForEach(EstimateUnits.all, id: \.self) { unit in
                        Text(unit.capitalized).tag(unit)
                    }
                }
                .labelsHidden()
                .onChange(of: subtasks[index].estimateUnit) { _, _ in
                    estimatesEdited = true
                }
            }
        }
    }

    /// Divide the parent's estimate evenly among subtasks
    private func divideEstimatesEvenly() {
        guard let amount = ticket.estimateAmountDouble, let unit = ticket.estimateUnit else { return }
        let count = Double(subtasks.count)
        let each = (amount / count * 100).rounded() / 100

        for i in 0..<subtasks.count {
            subtasks[i].estimateAmount = EstimateUnits.formatAmount(each)
            subtasks[i].estimateUnit = unit
        }
    }

    /// Total of subtask estimates when they share the same unit
    private var subtaskTotal: String? {
        let filled = subtasks.filter { !$0.estimateAmount.isEmpty }
        guard !filled.isEmpty else { return nil }

        let units = Set(filled.map { $0.estimateUnit })
        guard units.count == 1, let unit = units.first else { return "mixed units" }

        let sum = filled.compactMap { Double($0.estimateAmount) }.reduce(0, +)
        let rounded = (sum * 100).rounded() / 100
        return "\(EstimateUnits.formatAmount(rounded)) \(rounded == 1 ? EstimateUnits.singular(unit) : unit)"
    }

    private func split() async {
        isSplitting = true
        error = nil

        let entries: [(title: String, estimateAmount: String?, estimateUnit: String?)] = subtasks.map { row in
            let amount = row.estimateAmount.isEmpty ? nil : row.estimateAmount
            let unit = amount != nil ? row.estimateUnit : nil
            return (row.title.trimmingCharacters(in: .whitespaces), amount, unit)
        }

        do {
            _ = try await TicketAPIService.splitTicket(
                ticketId: ticket.id,
                mode: mode,
                subtasks: entries
            )
            onSplit()
        } catch let error as APIError {
            self.error = error.localizedDescription
        } catch {
            self.error = "Failed to split ticket"
        }

        isSplitting = false
    }
}

/// A row in the split ticket form
private struct SubtaskRow {
    var title: String
    var estimateAmount: String
    var estimateUnit: String
}

/// A staged contributor change (before Save)
struct StagedContributor: Equatable {
    let userId: Int
    var role: String
    let handle: String?
    let firstName: String?
    let lastName: String?

    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? (handle ?? "Unknown") : parts.joined(separator: " ")
    }
}

#Preview {
    NavigationStack {
        ProjectWorkspaceView(projectId: 1)
    }
}
