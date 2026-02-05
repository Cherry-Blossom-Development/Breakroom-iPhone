import SwiftUI

struct KanbanBoardView: View {
    let projectId: Int
    let projectTitle: String

    @State private var project: ProjectDetail?
    @State private var tickets: [Ticket] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showAddTicket = false
    @State private var editingTicket: Ticket?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading board...")
            } else {
                ScrollView(.vertical) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(TicketStatus.kanbanStatuses, id: \.self) { status in
                                kanbanColumn(status)
                            }
                        }
                        .padding()
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationTitle(projectTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Ticket", systemImage: "plus") {
                    showAddTicket = true
                }
            }
        }
        .task {
            await loadProject()
        }
        .refreshable {
            await loadProject()
        }
        .sheet(isPresented: $showAddTicket) {
            if let project {
                AddTicketSheet(companyId: project.companyId ?? 0, projectId: projectId) { newTicket in
                    tickets.insert(newTicket, at: 0)
                }
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

    private func kanbanColumn(_ status: TicketStatus) -> some View {
        let columnTickets = tickets.filter { $0.ticketStatus == status }

        return VStack(alignment: .leading, spacing: 8) {
            // Column header
            HStack {
                Circle()
                    .fill(statusColor(status))
                    .frame(width: 10, height: 10)
                Text(status.displayName)
                    .font(.headline)
                Spacer()
                Text("\(columnTickets.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Ticket cards
            if columnTickets.isEmpty {
                emptyColumnPlaceholder()
            } else {
                ForEach(columnTickets) { ticket in
                    ticketCard(ticket, status: status)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(width: 280)
    }

    private func emptyColumnPlaceholder() -> some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
            .foregroundStyle(.quaternary)
            .frame(height: 60)
            .overlay {
                Text("No tickets")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
    }

    private func ticketCard(_ ticket: Ticket, status: TicketStatus) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tappable card content
            Button {
                editingTicket = ticket
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(ticket.title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }

                    HStack {
                        priorityIndicator(ticket.ticketPriority)
                        Spacer()
                        if let assignee = ticket.assigneeDisplayName {
                            HStack(spacing: 4) {
                                Image(systemName: "person.circle.fill")
                                    .foregroundStyle(.secondary)
                                Text(assignee)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            // Status transition buttons (separate from tap area)
            statusTransitionButtons(ticket, currentStatus: status)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }

    private func statusTransitionButtons(_ ticket: Ticket, currentStatus: TicketStatus) -> some View {
        let transitions = allowedTransitions(from: currentStatus)

        return HStack(spacing: 6) {
            ForEach(transitions, id: \.self) { target in
                Button {
                    Task { await moveTicket(ticket, to: target) }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: transitionIcon(from: currentStatus, to: target))
                            .font(.caption2)
                        Text(target.displayName)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(statusColor(target).opacity(0.15))
                    .foregroundStyle(statusColor(target))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private func allowedTransitions(from status: TicketStatus) -> [TicketStatus] {
        switch status {
        case .backlog:
            return [.onDeck, .inProgress]
        case .onDeck:
            return [.backlog, .inProgress]
        case .inProgress:
            return [.onDeck, .resolved]
        case .resolved:
            return [.inProgress, .closed]
        case .closed:
            return [.resolved]
        case .open:
            return [.inProgress, .resolved]
        }
    }

    private func transitionIcon(from: TicketStatus, to: TicketStatus) -> String {
        let fromIndex = TicketStatus.kanbanStatuses.firstIndex(of: from) ?? 0
        let toIndex = TicketStatus.kanbanStatuses.firstIndex(of: to) ?? 0
        return toIndex > fromIndex ? "arrow.right" : "arrow.left"
    }

    private func priorityIndicator(_ priority: TicketPriority) -> some View {
        let color: Color = switch priority {
        case .low: .gray
        case .medium: .blue
        case .high: .orange
        case .urgent: .red
        }

        return HStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(priority.displayName)
                .font(.caption2)
                .foregroundStyle(color)
        }
    }

    private func statusColor(_ status: TicketStatus) -> Color {
        switch status {
        case .open, .backlog: return .orange
        case .onDeck: return .purple
        case .inProgress: return .blue
        case .resolved: return .green
        case .closed: return .gray
        }
    }

    private func loadProject() async {
        do {
            let response = try await TicketAPIService.getProjectWithTickets(projectId: projectId)
            project = response.project
            tickets = response.tickets
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }

    private func moveTicket(_ ticket: Ticket, to status: TicketStatus) async {
        do {
            let updated = try await TicketAPIService.updateTicketStatus(id: ticket.id, status: status.rawValue)
            if let idx = tickets.firstIndex(where: { $0.id == ticket.id }) {
                tickets[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
