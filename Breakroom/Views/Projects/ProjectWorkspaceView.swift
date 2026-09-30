import SwiftUI

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
    @State private var dependencies: [TicketDependency] = []
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
                dependencies: $dependencies,
                assignees: assignees,
                canWork: canWork,
                canManage: canManage,
                hasUnsavedChanges: $hasUnsavedChanges,
                onRefresh: { await loadProject() }
            )
        case .gantt:
            // Placeholder until GANTT is implemented
            placeholderView(title: "GANTT Chart", message: "Coming soon")
        case .burndown:
            // Placeholder until Burndown is implemented
            placeholderView(title: "Burndown Chart", message: "Coming soon")
        case .settings:
            // Placeholder until Settings is implemented
            placeholderView(title: "Project Settings", message: "Coming soon")
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
            dependencies = response.dependencies ?? []
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
    case gantt
    case burndown
    case settings

    var label: String {
        switch self {
        case .kanban: return "Kanban Board"
        case .gantt: return "GANTT Chart"
        case .burndown: return "Burndown Chart"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .kanban: return "rectangle.split.3x1"
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
    @Binding var dependencies: [TicketDependency]
    let assignees: [ProjectAssignee]
    let canWork: Bool
    let canManage: Bool
    @Binding var hasUnsavedChanges: Bool
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
                canManage: canManage
            ) { updatedTicket in
                if let index = tickets.firstIndex(where: { $0.id == updatedTicket.id }) {
                    tickets[index] = updatedTicket
                }
            }
        }
        .refreshable {
            await onRefresh()
        }
    }

    private var kanbanBoard: some View {
        let openTickets = tickets.filter { !$0.isResolved }
        let columns: [(status: TicketStatus, tickets: [Ticket])] = [
            (.backlog, openTickets.filter { $0.ticketStatus == .backlog }),
            (.open, openTickets.filter { $0.ticketStatus == .open }),
            (.onDeck, openTickets.filter { $0.ticketStatus == .onDeck }),
            (.inProgress, openTickets.filter { $0.ticketStatus == .inProgress })
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

    @Environment(\.dismiss) private var dismiss

    // Staged edits - local state until Save is clicked
    @State private var editedTitle: String
    @State private var editedDescription: String
    @State private var editedStatus: TicketStatus
    @State private var editedPriority: TicketPriority
    @State private var editedAssigneeId: Int?
    @State private var editedEstimateAmount: String
    @State private var editedEstimateUnit: String

    // UI state
    @State private var isSaving = false
    @State private var error: String?
    @State private var showUnsavedChangesAlert = false

    init(
        ticket: Ticket,
        assignees: [ProjectAssignee],
        dependencies: [TicketDependency],
        allTickets: [Ticket],
        canWork: Bool,
        canManage: Bool,
        onUpdate: @escaping (Ticket) -> Void
    ) {
        self.ticket = ticket
        self.assignees = assignees
        self.dependencies = dependencies
        self.allTickets = allTickets
        self.canWork = canWork
        self.canManage = canManage
        self.onUpdate = onUpdate

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
        editedEstimateUnit != (ticket.estimateUnit ?? "hours")
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
                if !dependencies.isEmpty {
                    Section("Blocked By") {
                        ForEach(dependencies) { dep in
                            HStack {
                                Image(systemName: dep.isSatisfied ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(dep.isSatisfied ? .green : .orange)
                                Text(dep.dependsOnTitle ?? "Ticket #\(dep.dependsOnTicketId)")
                            }
                        }
                    }
                }

                // Info section
                Section {
                    LabeledContent("Created by", value: ticket.creatorDisplayName)
                    if let createdAt = ticket.createdAt {
                        LabeledContent("Created", value: createdAt)
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
        }
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
            let updated = try await ProjectAPIService.updateTicketFields(ticketId: ticket.id, fields: fields)
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

#Preview {
    NavigationStack {
        ProjectWorkspaceView(projectId: 1)
    }
}
