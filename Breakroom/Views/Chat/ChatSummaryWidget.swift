import SwiftUI

/// A widget that shows rooms with unread messages one at a time, allowing the user
/// to quickly catch up on messages by reading/replying and pressing "Next" to move on.
struct ChatSummaryWidget: View {
    @Environment(ChatSocketManager.self) private var socketManager

    // Queue of rooms with unread messages
    @State private var queue: [UnreadRoomSummary] = []
    @State private var queueIndex = 0
    @State private var messages: [ChatMessage] = []

    // UI state
    @State private var newMessage = ""
    @State private var isLoading = true
    @State private var isLoadingMessages = false
    @State private var isSending = false
    @State private var error: String?

    // Computed
    private var currentRoom: UnreadRoomSummary? {
        guard queueIndex < queue.count else { return nil }
        return queue[queueIndex]
    }

    private var allDone: Bool {
        !isLoading && queue.isEmpty
    }

    private var positionLabel: String {
        guard !queue.isEmpty else { return "" }
        return "\(queueIndex + 1) of \(queue.count)"
    }

    /// Index of the first message that arrived after last_read_at (where the divider goes)
    private var firstUnreadIndex: Int {
        guard let room = currentRoom else { return -1 }
        guard let lastReadAt = room.lastReadAt else { return 0 }
        guard let cutoffDate = parseDate(lastReadAt) else { return 0 }

        return messages.firstIndex { msg in
            guard let createdAt = msg.createdAt,
                  let msgDate = parseDate(createdAt) else { return false }
            return msgDate > cutoffDate
        } ?? -1
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if let error {
                errorView(error)
            } else if allDone {
                allDoneView
            } else if let room = currentRoom {
                chatView(room: room)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            await fetchQueue()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Loading...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await fetchQueue() }
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
    }

    // MARK: - All Done View

    private var allDoneView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)
            Text("No New Messages")
                .font(.subheadline)
                .fontWeight(.medium)
            Button("Refresh") {
                Task { await fetchQueue() }
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
    }

    // MARK: - Chat View

    private func chatView(room: UnreadRoomSummary) -> some View {
        VStack(spacing: 0) {
            // Room header
            roomHeader(room: room)

            Divider()

            // Messages
            messagesView(roomId: room.id)

            Divider()

            // Input footer
            inputFooter(roomId: room.id)
        }
        .onAppear {
            socketManager.joinRoom(room.id)
            setupSocketListeners(roomId: room.id)
        }
        .onDisappear {
            socketManager.leaveRoom(room.id)
            socketManager.removeListeners(roomId: room.id)
        }
    }

    private func roomHeader(room: UnreadRoomSummary) -> some View {
        HStack {
            Text("# \(room.name)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Spacer()

            Text(positionLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    private func messagesView(roomId: Int) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                if isLoadingMessages {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, minHeight: 60)
                } else if messages.isEmpty {
                    Text("No messages yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            VStack(spacing: 0) {
                                // Unread divider
                                if index == firstUnreadIndex {
                                    unreadDivider
                                }

                                messageRow(message: message, isNew: firstUnreadIndex != -1 && index >= firstUnreadIndex)
                            }
                        }

                        // Bottom anchor
                        Color.clear
                            .frame(height: 1)
                            .id("bottomAnchor")
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 250)
            .onChange(of: messages.count) {
                // Scroll to unread divider or bottom when messages load
                if firstUnreadIndex != -1, let firstUnread = messages[safe: firstUnreadIndex] {
                    withAnimation {
                        proxy.scrollTo(firstUnread.id, anchor: .top)
                    }
                } else {
                    withAnimation {
                        proxy.scrollTo("bottomAnchor", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var unreadDivider: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.5))
                .frame(height: 1)

            Text("New Messages")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentColor)
                .textCase(.uppercase)

            Rectangle()
                .fill(Color.accentColor.opacity(0.5))
                .frame(height: 1)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
    }

    private func messageRow(message: ChatMessage, isNew: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(message.handle ?? "Unknown")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)

                Spacer()

                if let createdAt = message.createdAt {
                    Text(formatTime(createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let text = message.message, !text.isEmpty {
                Text(text)
                    .font(.caption)
            }

            Divider()
                .padding(.top, 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(isNew ? Color.accentColor.opacity(0.08) : Color.clear)
    }

    private func inputFooter(roomId: Int) -> some View {
        HStack(spacing: 8) {
            TextField("Reply...", text: $newMessage)
                .textFieldStyle(.plain)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(isSending)

            Button {
                Task { await sendMessage(roomId: roomId) }
            } label: {
                if isSending {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Send")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty || isSending)

            Button {
                Task { await goNext() }
            } label: {
                Text("Next")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Data Loading

    private func fetchQueue() async {
        isLoading = true
        error = nil
        do {
            let data = try await ChatAPIService.getUnreadSummary()
            queue = data
            queueIndex = 0
            if let first = data.first {
                await loadMessages(room: first)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func loadMessages(room: UnreadRoomSummary) async {
        isLoadingMessages = true
        messages = []
        do {
            let (msgs, _) = try await ChatAPIService.getMessages(roomId: room.id, limit: 20)
            messages = msgs
        } catch {
            // Silently fail
        }
        isLoadingMessages = false
    }

    // MARK: - Actions

    private func markRead() async {
        guard let room = currentRoom else { return }
        try? await ChatAPIService.markRoomRead(roomId: room.id)
    }

    private func goNext() async {
        await markRead()

        if let room = currentRoom {
            socketManager.leaveRoom(room.id)
            socketManager.removeListeners(roomId: room.id)
        }

        if queueIndex < queue.count - 1 {
            queueIndex += 1
            if let next = currentRoom {
                socketManager.joinRoom(next.id)
                setupSocketListeners(roomId: next.id)
                await loadMessages(room: next)
            }
        } else {
            // Exhausted the queue
            queue = []
            messages = []
        }
    }

    private func sendMessage(roomId: Int) async {
        let text = newMessage.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        isSending = true
        newMessage = ""

        do {
            let sent = try await ChatAPIService.sendMessage(roomId: roomId, message: text)
            if !messages.contains(where: { $0.id == sent.id }) {
                messages.append(sent)
            }
            try? await ChatAPIService.markRoomRead(roomId: roomId)
        } catch {
            newMessage = text // Restore on failure
        }

        isSending = false
    }

    // MARK: - Socket

    private func setupSocketListeners(roomId: Int) {
        socketManager.addMessageListener(roomId: roomId) { message in
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
        }

        socketManager.addEditListener(roomId: roomId) { message in
            if let idx = messages.firstIndex(where: { $0.id == message.id }) {
                messages[idx] = message
            }
        }

        socketManager.addDeleteListener(roomId: roomId) { messageId in
            messages.removeAll { $0.id == messageId }
        }
    }

    // MARK: - Helpers

    private func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func formatTime(_ iso: String) -> String {
        guard let date = parseDate(iso) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// Safe array subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
