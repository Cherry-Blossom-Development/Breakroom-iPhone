import SwiftUI

struct HelpDeskView: View {
    let companyId: Int
    let companyName: String

    @State private var tickets: [Ticket] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showAddTicket = false
    @State private var editingTicket: Ticket?

    private var openTickets: [Ticket] {
        tickets.filter { !$0.isResolved }
    }

    private var resolvedTickets: [Ticket] {
        tickets.filter { $0.isResolved }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading tickets...")
            } else if tickets.isEmpty {
                ContentUnavailableView(
                    "No Tickets",
                    systemImage: "ticket",
                    description: Text("Create a ticket to get started.")
                )
            } else {
                List {
                    if !openTickets.isEmpty {
                        Section {
                            ForEach(openTickets) { ticket in
                                ticketRow(ticket)
                            }
                        } header: {
                            HStack {
                                Text("Open")
                                Spacer()
                                Text("\(openTickets.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !resolvedTickets.isEmpty {
                        Section {
                            ForEach(resolvedTickets) { ticket in
                                ticketRow(ticket)
                            }
                        } header: {
                            HStack {
                                Text("Resolved")
                                Spacer()
                                Text("\(resolvedTickets.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Help Desk")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Ticket", systemImage: "plus") {
                    showAddTicket = true
                }
            }
        }
        .task {
            await loadTickets()
        }
        .refreshable {
            await loadTickets()
        }
        .sheet(isPresented: $showAddTicket) {
            AddTicketSheet(companyId: companyId, projectId: nil) { newTicket in
                tickets.insert(newTicket, at: 0)
            }
        }
        .sheet(item: $editingTicket) { ticket in
            EditTicketSheet(ticket: ticket) { updated in
                if let idx = tickets.firstIndex(where: { $0.id == updated.id }) {
                    tickets[idx] = updated
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    private func ticketRow(_ ticket: Ticket) -> some View {
        Button {
            editingTicket = ticket
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(ticket.title)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                    Spacer()
                    priorityBadge(ticket.ticketPriority)
                }

                HStack(spacing: 8) {
                    statusBadge(ticket.ticketStatus)
                    Spacer()
                    if let assignee = ticket.assigneeDisplayName {
                        Label(assignee, systemImage: "person")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if let desc = ticket.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }

                Text("Created by \(ticket.creatorDisplayName)")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
            .padding(.vertical, 4)
        }
        .foregroundStyle(.primary)
    }

    private func statusBadge(_ status: TicketStatus) -> some View {
        let color: Color = switch status {
        case .open, .backlog: .orange
        case .onDeck: .purple
        case .inProgress: .blue
        case .resolved: .green
        case .closed: .gray
        }

        return Text(status.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func priorityBadge(_ priority: TicketPriority) -> some View {
        let color: Color = switch priority {
        case .low: .gray
        case .medium: .blue
        case .high: .orange
        case .urgent: .red
        }

        return Text(priority.displayName)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func loadTickets() async {
        do {
            tickets = try await TicketAPIService.getHelpDeskTickets(companyId: companyId)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }
}

// MARK: - Add Ticket Sheet

struct AddTicketSheet: View {
    let companyId: Int
    let projectId: Int?
    let onAdd: (Ticket) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var priority: TicketPriority = .medium
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Ticket Info") {
                    TextField("Title *", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(TicketPriority.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private func save() async {
        isSaving = true
        let desc = description.trimmingCharacters(in: .whitespaces)

        do {
            let ticket: Ticket
            if let projectId {
                ticket = try await TicketAPIService.createProjectTicket(
                    projectId: projectId,
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: desc.isEmpty ? nil : desc,
                    priority: priority.rawValue,
                    assignedTo: nil
                )
            } else {
                ticket = try await TicketAPIService.createHelpDeskTicket(
                    companyId: companyId,
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: desc.isEmpty ? nil : desc,
                    priority: priority.rawValue,
                    assignedTo: nil
                )
            }
            onAdd(ticket)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}

// MARK: - Edit Ticket Sheet

struct EditTicketSheet: View {
    let ticket: Ticket
    let onSave: (Ticket) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var status: TicketStatus
    @State private var priority: TicketPriority
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    init(ticket: Ticket, onSave: @escaping (Ticket) -> Void) {
        self.ticket = ticket
        self.onSave = onSave
        _title = State(initialValue: ticket.title)
        _description = State(initialValue: ticket.description ?? "")
        _status = State(initialValue: ticket.ticketStatus)
        _priority = State(initialValue: ticket.ticketPriority)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ticket Info") {
                    TextField("Title *", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(TicketStatus.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(TicketPriority.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    LabeledContent("Created by", value: ticket.creatorDisplayName)
                    if let assignee = ticket.assigneeDisplayName {
                        LabeledContent("Assigned to", value: assignee)
                    }
                }
            }
            .navigationTitle("Edit Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private func save() async {
        isSaving = true
        let desc = description.trimmingCharacters(in: .whitespaces)

        do {
            let updated = try await TicketAPIService.updateTicket(
                id: ticket.id,
                title: title.trimmingCharacters(in: .whitespaces),
                description: desc.isEmpty ? nil : desc,
                status: status.rawValue,
                priority: priority.rawValue,
                assignedTo: nil
            )
            onSave(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}
