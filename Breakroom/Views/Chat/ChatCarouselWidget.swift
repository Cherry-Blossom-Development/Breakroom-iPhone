import SwiftUI

/// A carousel widget that displays chat rooms one at a time with left/right navigation.
/// Rooms are sorted by last message time (oldest left, newest right).
/// Starts on the rightmost (most recently active) room.
struct ChatCarouselWidget: View {
    @Environment(ChatSocketManager.self) private var socketManager

    // Room state - sorted ASC by created_at (oldest first, so newest is at end)
    @State private var rooms: [RecentRoomMessage] = []
    @State private var currentIndex: Int = 0
    @State private var messages: [ChatMessage] = []

    // UI state
    @State private var isLoading = true
    @State private var isLoadingMessages = false
    @State private var isSending = false
    @State private var messageText = ""
    @State private var error: String?
    @State private var rightGlowing = false

    // Navigation callback
    var onOpenRoom: ((Int) -> Void)?

    // Computed properties
    private var currentRoom: RecentRoomMessage? {
        guard currentIndex >= 0 && currentIndex < rooms.count else { return nil }
        return rooms[currentIndex]
    }

    private var canLeft: Bool {
        currentIndex > 0
    }

    private var canRight: Bool {
        currentIndex < rooms.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if let error {
                errorView(error)
            } else if rooms.isEmpty {
                emptyView
            } else {
                carouselContent
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            await loadRooms()
        }
        .onDisappear {
            cleanup()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Loading rooms...")
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
                Task { await loadRooms() }
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No chat rooms yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }

    // MARK: - Carousel Content

    private var carouselContent: some View {
        VStack(spacing: 0) {
            // Navigation header
            carouselHeader

            Divider()

            // Messages area
            messagesArea

            Divider()

            // Reply input
            replyInput
        }
    }

    // MARK: - Carousel Header

    private var carouselHeader: some View {
        HStack(spacing: 8) {
            // Left arrow
            Button {
                navigateLeft()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(canLeft ? Color.primary : Color.secondary.opacity(0.3))
            }
            .disabled(!canLeft)

            Spacer()

            // Room name (tappable to open full chat)
            if let room = currentRoom {
                Button {
                    onOpenRoom?(room.roomId)
                } label: {
                    Text("# \(room.roomName)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Position indicator
            Text("\(currentIndex + 1) / \(rooms.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Right arrow with glow
            Button {
                navigateRight()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(canRight ? Color.primary : Color.secondary.opacity(0.3))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(rightGlowing ? Color.yellow.opacity(0.4) : Color.clear)
                    )
            }
            .disabled(!canRight)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Messages Area

    private var messagesArea: some View {
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
                        ForEach(messages) { message in
                            messageRow(message: message)
                                .id(message.id)
                        }

                        // Bottom anchor for reliable scrolling
                        Color.clear
                            .frame(height: 1)
                            .id("bottomAnchor")
                            .onAppear {
                                // Scroll to bottom when anchor first appears
                                if !isLoadingMessages && !messages.isEmpty {
                                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                                }
                            }
                    }
                }
            }
            .defaultScrollAnchor(.bottom)
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 250)
            .onChange(of: isLoadingMessages) { oldValue, newValue in
                // Scroll to bottom when messages finish loading
                if oldValue == true && newValue == false && !messages.isEmpty {
                    // Multiple scroll attempts with increasing delays to handle lazy loading
                    scrollToBottom(proxy: proxy, delays: [0, 100, 300, 500])
                }
            }
            .onChange(of: messages.count) {
                // Scroll to bottom when new messages arrive
                if !messages.isEmpty {
                    withAnimation {
                        proxy.scrollTo("bottomAnchor", anchor: .bottom)
                    }
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, delays: [Int]) {
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) {
                proxy.scrollTo("bottomAnchor", anchor: .bottom)
            }
        }
    }

    private func messageRow(message: ChatMessage) -> some View {
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
    }

    // MARK: - Reply Input

    private var replyInput: some View {
        HStack(spacing: 8) {
            TextField("Message...", text: $messageText)
                .textFieldStyle(.plain)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(isSending)

            Button {
                Task { await sendMessage() }
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
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Navigation

    private func navigateLeft() {
        guard canLeft else { return }
        currentIndex -= 1
        loadCurrentRoomMessages()
    }

    private func navigateRight() {
        guard canRight else { return }
        currentIndex += 1
        // Clear glow when user navigates right
        rightGlowing = false
        loadCurrentRoomMessages()
    }

    private func loadCurrentRoomMessages() {
        guard let room = currentRoom else { return }
        Task {
            await loadMessages(for: room.roomId)
        }
    }

    // MARK: - Data Loading

    private func loadRooms() async {
        isLoading = true
        error = nil

        do {
            let fetchedRooms = try await ChatAPIService.getRecentRooms()
            // Rooms come sorted ASC by created_at (oldest first, newest last)
            rooms = fetchedRooms

            // Start on rightmost room (most recent)
            if !rooms.isEmpty {
                currentIndex = rooms.count - 1
                await loadMessages(for: rooms[currentIndex].roomId)
            }

            // Join ALL rooms to receive messages for any room
            joinAllRooms()
        } catch {
            self.error = "Failed to load rooms"
        }

        isLoading = false
    }

    private func loadMessages(for roomId: Int) async {
        isLoadingMessages = true
        messages = []

        do {
            let (msgs, _) = try await ChatAPIService.getMessages(roomId: roomId, limit: 30)
            messages = msgs
        } catch {
            // Silently fail - just show empty state
        }

        isLoadingMessages = false
    }

    private func sendMessage() async {
        guard let room = currentRoom else { return }
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        isSending = true
        messageText = ""

        do {
            let sent = try await ChatAPIService.sendMessage(roomId: room.roomId, message: text)
            if !messages.contains(where: { $0.id == sent.id }) {
                messages.append(sent)
            }
        } catch {
            messageText = text // Restore on failure
        }

        isSending = false
    }

    // MARK: - Socket Management

    private func joinAllRooms() {
        for room in rooms {
            socketManager.joinRoom(room.roomId)
            setupSocketListener(for: room.roomId)
        }
    }

    private func setupSocketListener(for roomId: Int) {
        socketManager.addMessageListener(roomId: roomId) { message in
            handleNewMessage(message, fromRoom: roomId)
        }

        socketManager.addEditListener(roomId: roomId) { message in
            if let room = currentRoom, message.roomId == room.roomId {
                if let idx = messages.firstIndex(where: { $0.id == message.id }) {
                    messages[idx] = message
                }
            }
        }

        socketManager.addDeleteListener(roomId: roomId) { messageId in
            if let room = currentRoom, roomId == room.roomId {
                messages.removeAll { $0.id == messageId }
            }
        }
    }

    private func handleNewMessage(_ message: ChatMessage, fromRoom roomId: Int) {
        // Find the room index before we modify anything
        guard let roomIndex = rooms.firstIndex(where: { $0.roomId == roomId }) else { return }

        let wasAtEnd = roomIndex == rooms.count - 1
        let isCurrentRoom = currentRoom?.roomId == roomId
        let currentRoomId = currentRoom?.roomId

        // Update the room with new message info and move to end
        var updatedRoom = rooms[roomIndex]
        updatedRoom.message = message.message
        updatedRoom.handle = message.handle ?? updatedRoom.handle
        updatedRoom.createdAt = message.createdAt ?? updatedRoom.createdAt

        rooms.remove(at: roomIndex)
        rooms.append(updatedRoom)

        // Adjust currentIndex to follow the current room after reordering
        if let currentRoomId = currentRoomId {
            if let newIndex = rooms.firstIndex(where: { $0.roomId == currentRoomId }) {
                currentIndex = newIndex
            }
        }

        // If this is the current room, add message to the list
        if isCurrentRoom {
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
        }

        // Trigger right glow if:
        // 1. Not the current room
        // 2. Room was NOT already at the end (meaning it moved right)
        if !isCurrentRoom && !wasAtEnd {
            triggerRightGlow()
        }
    }

    private func triggerRightGlow() {
        withAnimation(.easeIn(duration: 0.2)) {
            rightGlowing = true
        }

        // Fade out after 2 seconds
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.5)) {
                rightGlowing = false
            }
        }
    }

    private func cleanup() {
        // Leave all rooms and remove listeners
        for room in rooms {
            socketManager.leaveRoom(room.roomId)
            socketManager.removeListeners(roomId: room.roomId)
        }
    }

    // MARK: - Helpers

    private func formatTime(_ iso: String) -> String {
        guard let date = parseDate(iso) else { return "" }
        let formatter = DateFormatter()

        // If today, show just time; otherwise show date and time
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        return formatter.string(from: date)
    }

    private func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
