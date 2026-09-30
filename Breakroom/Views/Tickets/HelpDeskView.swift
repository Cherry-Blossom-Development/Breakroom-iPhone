import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct HelpDeskView: View {
    let companyId: Int
    let companyName: String

    @Environment(AuthViewModel.self) private var authViewModel
    // Respond to Increase Contrast accessibility setting
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @State private var tickets: [Ticket] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showAddTicket = false
    @State private var editingTicket: Ticket?
    @State private var viewingTicket: Ticket?

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
        .sheet(item: $viewingTicket) { ticket in
            ViewTicketSheet(ticket: ticket)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    private func canEditTicket(_ ticket: Ticket) -> Bool {
        guard let currentUserId = authViewModel.currentUserId,
              let creatorId = ticket.creatorId else { return false }
        return currentUserId == creatorId
    }

    private func ticketRow(_ ticket: Ticket) -> some View {
        Button {
            if canEditTicket(ticket) {
                editingTicket = ticket
            } else {
                viewingTicket = ticket
            }
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
                    Text(desc.strippingHTML())
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ticketAccessibilityLabel(ticket))
        .accessibilityHint(canEditTicket(ticket) ? "Double tap to edit" : "Double tap to view details")
    }

    private func ticketAccessibilityLabel(_ ticket: Ticket) -> String {
        var parts: [String] = [ticket.title]
        parts.append("Status: \(ticket.ticketStatus.displayName)")
        parts.append("Priority: \(ticket.ticketPriority.displayName)")
        if let assignee = ticket.assigneeDisplayName {
            parts.append("Assigned to \(assignee)")
        }
        parts.append("Created by \(ticket.creatorDisplayName)")
        return parts.joined(separator: ". ")
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
            .background(color.opacity(colorSchemeContrast == .increased ? 0.25 : 0.15))
            .foregroundStyle(colorSchemeContrast == .increased ? .primary : color)
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
            .background(color.opacity(colorSchemeContrast == .increased ? 0.2 : 0.1))
            .foregroundStyle(colorSchemeContrast == .increased ? .primary : color)
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
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var title: String
    @State private var description: String
    @State private var status: TicketStatus
    @State private var priority: TicketPriority
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showUnsavedChangesAlert = false

    // Comments state
    @State private var comments: [TicketComment] = []
    @State private var isLoadingComments = true
    @State private var newCommentText = ""
    @State private var isPostingComment = false
    @State private var editingCommentId: Int?
    @State private var editCommentText = ""

    // Attachments state (immediate upload in Help Desk)
    @State private var attachments: [TicketAttachment] = []
    @State private var isLoadingAttachments = false
    @State private var isUploadingAttachment = false
    @State private var attachmentError: String?
    @State private var isOpeningAttachment = false

    private var currentUsername: String? {
        authViewModel.currentUsername
    }

    private var hasUnsavedChanges: Bool {
        title != ticket.title ||
        description != (ticket.description?.strippingHTML() ?? "") ||
        status != ticket.ticketStatus ||
        priority != ticket.ticketPriority
    }

    init(ticket: Ticket, onSave: @escaping (Ticket) -> Void) {
        self.ticket = ticket
        self.onSave = onSave
        _title = State(initialValue: ticket.title)
        // Strip HTML for plain text editing
        _description = State(initialValue: ticket.description?.strippingHTML() ?? "")
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

                attachmentsSection

                commentsSection
            }
            .navigationTitle("Edit Ticket")
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
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving || !hasUnsavedChanges)
                }
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Do you want to discard them?")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .task {
                await loadComments()
                await loadAttachments()
            }
        }
    }

    // MARK: - Attachments Section

    @ViewBuilder
    private var attachmentsSection: some View {
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
                HelpDeskAttachmentsView(
                    attachments: attachments,
                    isUploading: isUploadingAttachment,
                    isOpening: isOpeningAttachment,
                    error: attachmentError,
                    onAdd: { files in
                        Task { await uploadAttachments(files) }
                    },
                    onRemove: { attachment in
                        Task { await deleteAttachment(attachment) }
                    },
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
    }

    // MARK: - Comments Section

    @ViewBuilder
    private var commentsSection: some View {
        let visibleComments = comments.filter { !$0.isDeletedBool }

        Section {
            if isLoadingComments {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if comments.isEmpty {
                Text("No comments yet")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(comments) { comment in
                    commentRow(comment)
                }
            }

            // Add comment input
            HStack(alignment: .top, spacing: 8) {
                TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task { await postComment() }
                } label: {
                    if isPostingComment {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(newCommentText.trimmingCharacters(in: .whitespaces).isEmpty || isPostingComment)
                .accessibilityLabel(isPostingComment ? "Posting comment" : "Post comment")
            }
        } header: {
            Text("Comments (\(visibleComments.count))")
        }
    }

    @ViewBuilder
    private func commentRow(_ comment: TicketComment) -> some View {
        if comment.isDeletedBool {
            Text("Comment deleted")
                .foregroundStyle(.secondary)
                .italic()
        } else if editingCommentId == comment.id {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Edit comment", text: $editCommentText, axis: .vertical)
                    .lineLimit(1...6)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save") {
                        Task { await saveEditedComment(comment.id) }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(editCommentText.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Save edited comment")

                    Button("Cancel") {
                        editingCommentId = nil
                        editCommentText = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Cancel editing")
                }
            }
            .padding(.vertical, 4)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.handle)
                        .font(.caption.weight(.semibold))
                        .accessibilityHidden(true)

                    if let date = comment.createdAt {
                        Text(formatCommentDate(date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }

                    if comment.wasEdited {
                        Text("(edited)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .italic()
                            .accessibilityHidden(true)
                    }

                    Spacer()

                    if comment.handle == currentUsername {
                        Menu {
                            Button("Edit") {
                                editingCommentId = comment.id
                                editCommentText = comment.content
                            }
                            Button("Delete", role: .destructive) {
                                Task { await deleteComment(comment.id) }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Comment actions")
                    }
                }

                Text(comment.content)
                    .font(.subheadline)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(commentAccessibilityLabel(comment))
        }
    }

    private func commentAccessibilityLabel(_ comment: TicketComment) -> String {
        var parts: [String] = ["\(comment.handle) commented"]
        parts.append(comment.content)
        if comment.wasEdited {
            parts.append("edited")
        }
        if let date = comment.createdAt {
            parts.append(formatCommentDate(date))
        }
        return parts.joined(separator: ". ")
    }

    private func formatCommentDate(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateStr
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

    private func loadComments() async {
        do {
            comments = try await TicketAPIService.getComments(ticketId: ticket.id)
        } catch {
            // Silently fail - comments are supplementary
        }
        isLoadingComments = false
    }

    private func postComment() async {
        let content = newCommentText.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }

        isPostingComment = true
        do {
            let comment = try await TicketAPIService.addComment(ticketId: ticket.id, content: content)
            comments.append(comment)
            newCommentText = ""
        } catch {
            // Could show error alert
        }
        isPostingComment = false
    }

    private func saveEditedComment(_ commentId: Int) async {
        let content = editCommentText.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }

        do {
            let updated = try await TicketAPIService.editComment(commentId: commentId, content: content)
            if let idx = comments.firstIndex(where: { $0.id == commentId }) {
                comments[idx] = updated
            }
            editingCommentId = nil
            editCommentText = ""
        } catch {
            // Could show error alert
        }
    }

    private func deleteComment(_ commentId: Int) async {
        do {
            try await TicketAPIService.deleteComment(commentId: commentId)
            if let idx = comments.firstIndex(where: { $0.id == commentId }) {
                // Mark as deleted locally
                let old = comments[idx]
                comments[idx] = TicketComment(
                    id: old.id,
                    ticketId: old.ticketId,
                    userId: old.userId,
                    content: old.content,
                    isDeleted: 1,
                    createdAt: old.createdAt,
                    updatedAt: old.updatedAt,
                    handle: old.handle
                )
            }
        } catch {
            // Could show error alert
        }
    }

    // MARK: - Attachments

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

    private func uploadAttachments(_ files: [PendingFile]) async {
        isUploadingAttachment = true
        attachmentError = nil

        do {
            let uploadFiles = files.map { (data: $0.data, fileName: $0.fileName, mimeType: $0.mimeType) }
            let updated = try await ProjectAPIService.uploadAttachments(ticketId: ticket.id, files: uploadFiles)
            attachments = updated
        } catch {
            attachmentError = "Failed to upload attachments"
        }

        isUploadingAttachment = false
    }

    private func deleteAttachment(_ attachment: TicketAttachment) async {
        attachmentError = nil

        do {
            let updated = try await ProjectAPIService.deleteAttachment(attachmentId: attachment.id)
            attachments = updated
        } catch {
            attachmentError = "Failed to delete attachment"
        }
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
}

// MARK: - View Ticket Sheet (Read-Only)

struct ViewTicketSheet: View {
    let ticket: Ticket

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var comments: [TicketComment] = []
    @State private var isLoadingComments = true
    @State private var newCommentText = ""
    @State private var isPostingComment = false
    @State private var editingCommentId: Int?
    @State private var editCommentText = ""

    private var currentUsername: String? {
        authViewModel.currentUsername
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Ticket Info") {
                    LabeledContent("Title", value: ticket.title)

                    if let desc = ticket.description, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(desc.strippingHTML())
                                .font(.body)
                        }
                    }
                }

                Section("Status") {
                    LabeledContent("Status", value: ticket.ticketStatus.displayName)
                    LabeledContent("Priority", value: ticket.ticketPriority.displayName)
                }

                Section {
                    LabeledContent("Created by", value: ticket.creatorDisplayName)
                    if let assignee = ticket.assigneeDisplayName {
                        LabeledContent("Assigned to", value: assignee)
                    }
                }

                commentsSection
            }
            .navigationTitle("Ticket Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadComments()
            }
        }
    }

    @ViewBuilder
    private var commentsSection: some View {
        let visibleComments = comments.filter { !$0.isDeletedBool }

        Section {
            if isLoadingComments {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if comments.isEmpty {
                Text("No comments yet")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(comments) { comment in
                    commentRow(comment)
                }
            }

            // Add comment input
            HStack(alignment: .top, spacing: 8) {
                TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task { await postComment() }
                } label: {
                    if isPostingComment {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(newCommentText.trimmingCharacters(in: .whitespaces).isEmpty || isPostingComment)
                .accessibilityLabel(isPostingComment ? "Posting comment" : "Post comment")
            }
        } header: {
            Text("Comments (\(visibleComments.count))")
        }
    }

    @ViewBuilder
    private func commentRow(_ comment: TicketComment) -> some View {
        if comment.isDeletedBool {
            Text("Comment deleted")
                .foregroundStyle(.secondary)
                .italic()
        } else if editingCommentId == comment.id {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Edit comment", text: $editCommentText, axis: .vertical)
                    .lineLimit(1...6)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save") {
                        Task { await saveEditedComment(comment.id) }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(editCommentText.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Save edited comment")

                    Button("Cancel") {
                        editingCommentId = nil
                        editCommentText = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Cancel editing")
                }
            }
            .padding(.vertical, 4)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.handle)
                        .font(.caption.weight(.semibold))
                        .accessibilityHidden(true)

                    if let date = comment.createdAt {
                        Text(formatCommentDate(date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }

                    if comment.wasEdited {
                        Text("(edited)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .italic()
                            .accessibilityHidden(true)
                    }

                    Spacer()

                    if comment.handle == currentUsername {
                        Menu {
                            Button("Edit") {
                                editingCommentId = comment.id
                                editCommentText = comment.content
                            }
                            Button("Delete", role: .destructive) {
                                Task { await deleteComment(comment.id) }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Comment actions")
                    }
                }

                Text(comment.content)
                    .font(.subheadline)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(commentAccessibilityLabel(comment))
        }
    }

    private func commentAccessibilityLabel(_ comment: TicketComment) -> String {
        var parts: [String] = ["\(comment.handle) commented"]
        parts.append(comment.content)
        if comment.wasEdited {
            parts.append("edited")
        }
        if let date = comment.createdAt {
            parts.append(formatCommentDate(date))
        }
        return parts.joined(separator: ". ")
    }

    private func formatCommentDate(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateStr
    }

    private func loadComments() async {
        do {
            comments = try await TicketAPIService.getComments(ticketId: ticket.id)
        } catch {
            // Silently fail - comments are supplementary
        }
        isLoadingComments = false
    }

    private func postComment() async {
        let content = newCommentText.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }

        isPostingComment = true
        do {
            let comment = try await TicketAPIService.addComment(ticketId: ticket.id, content: content)
            comments.append(comment)
            newCommentText = ""
            AccessibilityNotification.Announcement("Comment posted").post()
        } catch {
            AccessibilityNotification.Announcement("Failed to post comment").post()
        }
        isPostingComment = false
    }

    private func saveEditedComment(_ commentId: Int) async {
        let content = editCommentText.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }

        do {
            let updated = try await TicketAPIService.editComment(commentId: commentId, content: content)
            if let idx = comments.firstIndex(where: { $0.id == commentId }) {
                comments[idx] = updated
            }
            editingCommentId = nil
            editCommentText = ""
            AccessibilityNotification.Announcement("Comment updated").post()
        } catch {
            AccessibilityNotification.Announcement("Failed to update comment").post()
        }
    }

    private func deleteComment(_ commentId: Int) async {
        do {
            try await TicketAPIService.deleteComment(commentId: commentId)
            if let idx = comments.firstIndex(where: { $0.id == commentId }) {
                // Mark as deleted locally
                let old = comments[idx]
                comments[idx] = TicketComment(
                    id: old.id,
                    ticketId: old.ticketId,
                    userId: old.userId,
                    content: old.content,
                    isDeleted: 1,
                    createdAt: old.createdAt,
                    updatedAt: old.updatedAt,
                    handle: old.handle
                )
            }
            AccessibilityNotification.Announcement("Comment deleted").post()
        } catch {
            AccessibilityNotification.Announcement("Failed to delete comment").post()
        }
    }
}


// MARK: - Help Desk Attachments View (Immediate Upload)

struct HelpDeskAttachmentsView: View {
    let attachments: [TicketAttachment]
    let isUploading: Bool
    let isOpening: Bool
    let error: String?
    let onAdd: ([PendingFile]) -> Void
    let onRemove: (TicketAttachment) -> Void
    let onOpen: (TicketAttachment) -> Void

    @State private var showFilePicker = false
    @State private var localError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Attachments")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    localError = nil
                    showFilePicker = true
                } label: {
                    Label(isUploading ? "Uploading..." : "Attach files", systemImage: "paperclip")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isUploading || isOpening)
            }

            // Empty state
            if attachments.isEmpty {
                Text("No attachments. Tap Attach files (up to 25 MB each).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Attachments list
            ForEach(attachments) { attachment in
                attachmentRow(attachment)
            }

            // Error message
            if let error = localError ?? error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            handleFilePicked(result)
        }
    }

    private func attachmentRow(_ attachment: TicketAttachment) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: attachment.isImage ? "photo" : "doc")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(attachment.formattedSize)
                    if let uploader = attachment.uploaderHandle {
                        Text("·")
                        Text("@\(uploader)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Remove button
            Button {
                onRemove(attachment)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isUploading || isOpening)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onOpen(attachment)
        }
    }

    private func handleFilePicked(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var newFiles: [PendingFile] = []

            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                do {
                    let data = try Data(contentsOf: url)
                    let fileName = url.lastPathComponent
                    let mimeType = mimeTypeForURL(url)

                    newFiles.append(PendingFile(
                        data: data,
                        fileName: fileName,
                        mimeType: mimeType
                    ))
                } catch {
                    localError = "Failed to read file: \(url.lastPathComponent)"
                    return
                }
            }

            // Check limits
            if let limitError = attachmentLimitError(newFiles, alreadyPending: 0) {
                localError = limitError
                return
            }

            onAdd(newFiles)

        case .failure(let error):
            localError = "Failed to pick files: \(error.localizedDescription)"
        }
    }

    private func mimeTypeForURL(_ url: URL) -> String {
        if let uti = UTType(filenameExtension: url.pathExtension) {
            return uti.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }
}

