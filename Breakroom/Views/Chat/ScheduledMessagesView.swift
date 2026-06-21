import SwiftUI

// MARK: - Form Sheet

struct ScheduledMessageFormSheet: View {
    @Binding var messageText: String
    @Binding var selectedRoomId: Int?
    @Binding var scheduledAt: Date
    @Binding var warningMinutes: Int
    @Binding var indicatorText: String

    let rooms: [ChatRoom]
    let isEditing: Bool
    let isSaving: Bool
    let formError: String?
    let onSave: () async -> Void
    let onCancel: () -> Void

    private let defaultIndicator = "- sent via scheduled message"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Message text area
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Message")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ZStack(alignment: .topLeading) {
                            if messageText.isEmpty {
                                Text("Type your message...")
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 12)
                            }
                            TextEditor(text: $messageText)
                                .frame(minHeight: 100, maxHeight: 150)
                                .scrollContentBackground(.hidden)
                                .padding(4)
                        }
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        HStack {
                            Spacer()
                            Text("\(messageText.count)/1000")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    // Room picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Room")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("Room", selection: $selectedRoomId) {
                            Text("Select room").tag(nil as Int?)
                            ForEach(rooms) { room in
                                Text("# \(room.name)").tag(room.id as Int?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.primary)
                    }

                    // Send time
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Send at")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        DatePicker(
                            "",
                            selection: $scheduledAt,
                            in: Date().addingTimeInterval(120)...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                    }

                    // Warning time
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Warn me")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            TextField("", value: $warningMinutes, format: .number)
                                .keyboardType(.numberPad)
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)

                            Text("minutes before sending")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Indicator text
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Indicator text")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("(appended to message)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        HStack(spacing: 8) {
                            TextField("e.g. - sent via scheduled message", text: $indicatorText)
                                .textFieldStyle(.roundedBorder)

                            Button("Default") {
                                indicatorText = defaultIndicator
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)

                            Button("None") {
                                indicatorText = ""
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }

                    if let formError {
                        Text(formError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle(isEditing ? "Edit Scheduled Message" : "Schedule a Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Schedule") {
                        Task { await onSave() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}

// MARK: - Main View

struct ScheduledMessagesView: View {
    @State private var scheduledMessages: [ScheduledMessage] = []
    @State private var rooms: [ChatRoom] = []
    @State private var isLoading = true
    @State private var error: String?

    // Sheet state
    @State private var showingFormSheet = false

    // Form state
    @State private var messageText = ""
    @State private var selectedRoomId: Int?
    @State private var scheduledAt = Date().addingTimeInterval(3600)
    @State private var warningMinutes = 10
    @State private var indicatorText = "- sent via scheduled message"

    // Edit state
    @State private var editingId: Int?
    @State private var isSaving = false
    @State private var formError: String?

    private let defaultIndicator = "- sent via scheduled message"

    var body: some View {
        VStack(spacing: 0) {
            listSection

            Divider()

            Button {
                openCreate()
            } label: {
                Text("Create new Message")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .navigationTitle("Scheduled Messages")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .sheet(isPresented: $showingFormSheet) {
            ScheduledMessageFormSheet(
                messageText: $messageText,
                selectedRoomId: $selectedRoomId,
                scheduledAt: $scheduledAt,
                warningMinutes: $warningMinutes,
                indicatorText: $indicatorText,
                rooms: rooms,
                isEditing: editingId != nil,
                isSaving: isSaving,
                formError: formError,
                onSave: saveMessage,
                onCancel: closeSheet
            )
        }
    }

    // MARK: - List Section

    private var listSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Upcoming")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal)
                    .padding(.top)

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                } else if let error {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding()
                } else if scheduledMessages.isEmpty {
                    Text("No scheduled messages.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(scheduledMessages) { msg in
                            scheduledMessageRow(msg)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .refreshable {
            await loadData()
        }
    }

    private func scheduledMessageRow(_ msg: ScheduledMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("#\(msg.roomName ?? "Unknown")")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(statusLabel(for: msg))
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusBackgroundColor(for: msg))
                    .foregroundStyle(statusTextColor(for: msg))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Text(formatSendTime(msg.scheduledAt))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(msg.messageText)
                .font(.subheadline)
                .lineLimit(2)

            HStack(spacing: 8) {
                Button("Edit") {
                    openEdit(msg)
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .disabled(msg.status == "warning_sent" && !msg.isEditing)

                Button("Cancel") {
                    Task { await cancelMessage(msg.id) }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .background(rowBackgroundColor(for: msg))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(rowBorderColor(for: msg), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private func statusLabel(for msg: ScheduledMessage) -> String {
        if msg.isEditing {
            return "Editing paused"
        }
        switch msg.status {
        case "warning_sent": return "Sending soon"
        case "confirmed": return "Confirmed"
        default: return "Scheduled"
        }
    }

    private func statusBackgroundColor(for msg: ScheduledMessage) -> Color {
        if msg.isEditing {
            return Color.accentColor.opacity(0.2)
        }
        switch msg.status {
        case "warning_sent": return Color.orange.opacity(0.2)
        case "confirmed": return Color.green.opacity(0.2)
        default: return Color(.secondarySystemBackground)
        }
    }

    private func statusTextColor(for msg: ScheduledMessage) -> Color {
        if msg.isEditing {
            return .accentColor
        }
        switch msg.status {
        case "warning_sent": return .orange
        case "confirmed": return .green
        default: return .secondary
        }
    }

    private func rowBackgroundColor(for msg: ScheduledMessage) -> Color {
        if msg.isEditing {
            return Color.accentColor.opacity(0.05)
        }
        if msg.status == "warning_sent" {
            return Color.orange.opacity(0.05)
        }
        return Color(.secondarySystemBackground)
    }

    private func rowBorderColor(for msg: ScheduledMessage) -> Color {
        if msg.isEditing {
            return .accentColor
        }
        if msg.status == "warning_sent" {
            return Color.orange.opacity(0.5)
        }
        return Color(.separator)
    }

    private func formatSendTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString) else {
            return dateString
        }

        let calendar = Calendar.current

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "Today at \(timeString)"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow at \(timeString)"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            return "\(dateFormatter.string(from: date)) at \(timeString)"
        }
    }

    // MARK: - Sheet Management

    private func openCreate() {
        resetForm()
        showingFormSheet = true
    }

    private func openEdit(_ msg: ScheduledMessage) {
        editingId = msg.id
        messageText = msg.messageText
        selectedRoomId = msg.roomId
        warningMinutes = msg.warningMinutes
        indicatorText = msg.indicatorText ?? defaultIndicator

        // Parse the scheduled time
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: msg.scheduledAt) ?? ISO8601DateFormatter().date(from: msg.scheduledAt) {
            scheduledAt = date
        }

        formError = nil
        showingFormSheet = true
    }

    private func closeSheet() {
        showingFormSheet = false
        resetForm()
    }

    // MARK: - Actions

    private func loadData() async {
        isLoading = true
        error = nil

        do {
            async let roomsTask = ChatAPIService.getRooms()
            async let messagesTask = ChatAPIService.getScheduledMessages()

            let (loadedRooms, loadedMessages) = try await (roomsTask, messagesTask)
            rooms = loadedRooms
            scheduledMessages = loadedMessages

            if selectedRoomId == nil, let firstRoom = rooms.first {
                selectedRoomId = firstRoom.id
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func resetForm() {
        editingId = nil
        messageText = ""
        selectedRoomId = rooms.first?.id
        scheduledAt = Date().addingTimeInterval(3600)
        warningMinutes = 10
        indicatorText = defaultIndicator
        formError = nil
    }

    private func saveMessage() async {
        formError = nil

        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            formError = "Message is required"
            return
        }

        guard messageText.count <= 1000 else {
            formError = "Message must be 1000 characters or less"
            return
        }

        guard let roomId = selectedRoomId else {
            formError = "Please select a room"
            return
        }

        guard scheduledAt > Date() else {
            formError = "Send time must be in the future"
            return
        }

        isSaving = true

        do {
            if let editId = editingId {
                _ = try await ChatAPIService.updateScheduledMessage(
                    id: editId,
                    roomId: roomId,
                    messageText: messageText.trimmingCharacters(in: .whitespacesAndNewlines),
                    scheduledAt: scheduledAt,
                    warningMinutes: max(0, min(60, warningMinutes)),
                    indicatorText: indicatorText
                )
            } else {
                _ = try await ChatAPIService.createScheduledMessage(
                    roomId: roomId,
                    messageText: messageText.trimmingCharacters(in: .whitespacesAndNewlines),
                    scheduledAt: scheduledAt,
                    warningMinutes: max(0, min(60, warningMinutes)),
                    indicatorText: indicatorText
                )
            }

            showingFormSheet = false
            resetForm()
            await loadData()
        } catch {
            formError = error.localizedDescription
        }

        isSaving = false
    }

    private func cancelMessage(_ id: Int) async {
        do {
            try await ChatAPIService.cancelScheduledMessage(id: id)
            if editingId == id {
                resetForm()
            }
            await loadData()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ScheduledMessagesView()
    }
}
