import SwiftUI
import PhotosUI
import AVKit

struct ChatWidget: View {
    let block: BreakroomBlock
    @Environment(ChatSocketManager.self) private var socketManager
    @Environment(BadgeStore.self) private var badgeStore
    @State private var messages: [ChatMessage] = []
    @State private var messageText = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var error: String?
    @State private var typingUsers: [String] = []
    @State private var typingStopTask: Task<Void, Never>?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingMedia: Bool = false

    // Pagination state
    @State private var hasOlderMessages = false
    @State private var oldestMessageDate: String?
    @State private var isLoadingOlderMessages = false
    @State private var suppressScrollToBottom = false

    // Message actions
    @State private var messageToFlag: ChatMessage?
    @State private var messageToEdit: ChatMessage?
    @State private var editedMessageText = ""
    @State private var messageToDelete: ChatMessage?
    @State private var showDeleteConfirmation = false
    @State private var showBlockConfirmation = false
    @State private var userToBlock: (id: Int, handle: String)?

    private var roomId: Int? { block.contentId }

    var body: some View {
        if let roomId {
            chatContent(roomId: roomId)
        } else {
            noRoomView
        }
    }

    private func chatContent(roomId: Int) -> some View {
        VStack(spacing: 0) {
            messageList
            if !typingUsers.isEmpty {
                typingIndicator
            }
            Divider()
            if isUploadingMedia {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Uploading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
            messageInput(roomId: roomId)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .task {
            await loadMessages(roomId: roomId)
            await badgeStore.markRoomRead(roomId)
            socketManager.joinRoom(roomId)

            // Register listeners for this room
            socketManager.addMessageListener(roomId: roomId) { message in
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                }
            }
            socketManager.addEditListener(roomId: roomId) { message in
                if let index = messages.firstIndex(where: { $0.id == message.id }) {
                    messages[index] = message
                }
            }
            socketManager.addDeleteListener(roomId: roomId) { messageId in
                messages.removeAll { $0.id == messageId }
            }
            socketManager.addTypingListener(roomId: roomId) { user, isTyping in
                if isTyping {
                    if !typingUsers.contains(user) {
                        typingUsers.append(user)
                    }
                } else {
                    typingUsers.removeAll { $0 == user }
                }
            }
        }
        .onDisappear {
            socketManager.leaveRoom(roomId)
            socketManager.removeListeners(roomId: roomId)
        }
        .sheet(item: $messageToFlag) { message in
            FlagDialogView(
                contentType: .chatMessage,
                contentId: message.id,
                onDismiss: {
                    messageToFlag = nil
                },
                onFlagged: {
                    messages.removeAll { $0.id == message.id }
                }
            )
            .presentationDetents([.medium])
        }
        .alert("Edit Message", isPresented: Binding(
            get: { messageToEdit != nil },
            set: { if !$0 { messageToEdit = nil } }
        )) {
            TextField("Message", text: $editedMessageText)
            Button("Cancel", role: .cancel) {
                messageToEdit = nil
                editedMessageText = ""
            }
            Button("Save") {
                if let message = messageToEdit {
                    Task {
                        await editMessage(roomId: roomId, messageId: message.id, newText: editedMessageText)
                        messageToEdit = nil
                        editedMessageText = ""
                    }
                }
            }
        }
        .alert("Delete Message", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                messageToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let message = messageToDelete {
                    Task {
                        await deleteMessage(roomId: roomId, messageId: message.id)
                        messageToDelete = nil
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this message? This cannot be undone.")
        }
        .confirmationDialog(
            "Block @\(userToBlock?.handle ?? "")?",
            isPresented: $showBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                if let user = userToBlock {
                    Task {
                        try? await FriendsAPIService.blockUser(userId: user.id)
                        // Remove all messages from this user
                        messages.removeAll { $0.userId == user.id }
                        userToBlock = nil
                    }
                }
            }
        } message: {
            Text("They won't be able to see your content or contact you. You can unblock them from your Friends page.")
        }
    }

    private var typingIndicator: some View {
        let text = typingUsers.joined(separator: ", ")
            + (typingUsers.count == 1 ? " is" : " are")
            + " typing..."
        return Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .italic()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else if messages.isEmpty {
                    Text("No messages yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Loading indicator at top when fetching older messages
                        if isLoadingOlderMessages {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading older messages...")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }

                        // Sentinel view to detect scroll to top
                        if hasOlderMessages && !isLoadingOlderMessages {
                            Color.clear
                                .frame(height: 1)
                                .id("topSentinel")
                                .onAppear {
                                    guard let roomId else { return }
                                    Task { await loadOlderMessages(roomId: roomId) }
                                }
                        }

                        ForEach(messages) { message in
                            ChatWidgetMessageRow(
                                message: message,
                                onFlag: { messageToFlag = message },
                                onEdit: {
                                    editedMessageText = message.message ?? ""
                                    messageToEdit = message
                                },
                                onDelete: {
                                    messageToDelete = message
                                    showDeleteConfirmation = true
                                },
                                onBlock: {
                                    if let userId = message.userId, let handle = message.handle {
                                        userToBlock = (id: userId, handle: handle)
                                        showBlockConfirmation = true
                                    }
                                }
                            )
                            .id(message.id)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 300)
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.bottom)
            .onChange(of: messages.count) {
                if suppressScrollToBottom {
                    suppressScrollToBottom = false
                } else if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func messageInput(roomId: Int) -> some View {
        HStack(spacing: 12) {
            // Media picker button - constrained to prevent tap target expansion
            PhotosPicker(selection: $selectedPhoto, matching: .any(of: [.images, .videos])) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .disabled(isUploadingMedia)
            .accessibilityIdentifier("widgetMediaButton")

            TextField("Message", text: $messageText)
                .textFieldStyle(.plain)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityIdentifier("widgetMessageInput")
                .onChange(of: messageText) {
                    guard !messageText.isEmpty else { return }
                    socketManager.startTyping(roomId: roomId)
                    typingStopTask?.cancel()
                    typingStopTask = Task {
                        try? await Task.sleep(for: .seconds(2))
                        guard !Task.isCancelled else { return }
                        socketManager.stopTyping(roomId: roomId)
                    }
                }

            // Send button - explicit button style to ensure proper touch handling
            Button {
                Task { await sendMessage(roomId: roomId) }
            } label: {
                Group {
                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                    }
                }
                .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            .accessibilityIdentifier("widgetSendButton")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .onChange(of: selectedPhoto) {
            guard let item = selectedPhoto else { return }
            selectedPhoto = nil
            Task { await handlePickedMedia(item, roomId: roomId) }
        }
    }

    private var noRoomView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No chat room assigned")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding()
    }

    // MARK: - Data

    private func loadMessages(roomId: Int) async {
        isLoading = true
        hasOlderMessages = false
        oldestMessageDate = nil
        do {
            let (msgs, hasMore) = try await ChatAPIService.getMessages(roomId: roomId)
            messages = msgs
            hasOlderMessages = hasMore
            oldestMessageDate = msgs.first?.createdAt
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func loadOlderMessages(roomId: Int) async {
        guard let oldest = oldestMessageDate,
              hasOlderMessages,
              !isLoadingOlderMessages else { return }

        isLoadingOlderMessages = true
        suppressScrollToBottom = true

        do {
            let (olderMsgs, hasMore) = try await ChatAPIService.getMessages(roomId: roomId, before: oldest)
            let existingIds = Set(messages.map(\.id))
            let newMessages = olderMsgs.filter { !existingIds.contains($0.id) }
            if !newMessages.isEmpty {
                messages = newMessages + messages
                oldestMessageDate = newMessages.first?.createdAt
            }
            hasOlderMessages = hasMore
        } catch {
            // Silently fail
        }

        isLoadingOlderMessages = false
    }

    private func handlePickedMedia(_ item: PhotosPickerItem, roomId: Int) async {
        isUploadingMedia = true
        defer { isUploadingMedia = false }

        guard let data = try? await item.loadTransferable(type: Data.self) else { return }

        do {
            let message: ChatMessage
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                message = try await ChatAPIService.uploadVideo(roomId: roomId, videoData: data, filename: "video.mp4")
            } else {
                message = try await ChatAPIService.uploadImage(roomId: roomId, imageData: data, filename: "image.jpg")
            }
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func sendMessage(roomId: Int) async {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        isSending = true
        messageText = ""

        // Stop typing indicator
        typingStopTask?.cancel()
        socketManager.stopTyping(roomId: roomId)

        if socketManager.connectionState == .connected {
            // Send via socket — message comes back via new_message event
            socketManager.sendMessage(roomId: roomId, message: text)
        } else {
            // Fallback to REST when socket is disconnected
            do {
                let sent = try await ChatAPIService.sendMessage(roomId: roomId, message: text)
                if !messages.contains(where: { $0.id == sent.id }) {
                    messages.append(sent)
                }
            } catch {
                messageText = text
                self.error = error.localizedDescription
            }
        }

        isSending = false
    }

    private func editMessage(roomId: Int, messageId: Int, newText: String) async {
        do {
            let updated = try await ChatAPIService.editMessage(roomId: roomId, messageId: messageId, message: newText)
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index] = updated
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteMessage(roomId: Int, messageId: Int) async {
        do {
            try await ChatAPIService.deleteMessage(roomId: roomId, messageId: messageId)
            messages.removeAll { $0.id == messageId }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Message Row

struct ChatWidgetMessageRow: View {
    let message: ChatMessage
    let onFlag: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onBlock: () -> Void

    private var isCurrentUser: Bool {
        guard let storedId = KeychainManager.get(.userId),
              let currentUserId = Int(storedId) else { return false }
        return message.userId == currentUserId
    }

    private var isTextOnlyMessage: Bool {
        let hasImage = message.imagePath != nil && !message.imagePath!.isEmpty
        let hasVideo = message.videoPath != nil && !message.videoPath!.isEmpty
        return !hasImage && !hasVideo
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            headerRow
            messageContent
            Divider()
                .padding(.top, 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private var headerRow: some View {
        HStack {
            if let handle = message.handle {
                NavigationLink(value: handle) {
                    Text(handle)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
            } else {
                Text("Unknown")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            Spacer()
            Text(formattedTime)
                .font(.caption2)
                .foregroundStyle(.secondary)
            // Meatballs menu for all messages
            Menu {
                if isCurrentUser {
                    if isTextOnlyMessage {
                        Button {
                            onEdit()
                        } label: {
                            Label("Edit Message", systemImage: "pencil")
                        }
                    }
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete Message", systemImage: "trash")
                    }
                } else {
                    Button(role: .destructive) {
                        onFlag()
                    } label: {
                        Label("Report Message", systemImage: "flag")
                    }
                    Button(role: .destructive) {
                        onBlock()
                    } label: {
                        Label("Block User", systemImage: "hand.raised.slash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        if let imagePath = message.imagePath, !imagePath.isEmpty {
            AuthenticatedImage(path: imagePath, maxWidth: .infinity, maxHeight: 100, cornerRadius: 8)
                .padding(.top, 2)
        }

        if let videoPath = message.videoPath, !videoPath.isEmpty {
            AuthenticatedVideoPlayer(path: videoPath, width: 200, height: 120, cornerRadius: 8)
                .padding(.top, 2)
        }

        if let text = message.message, !text.isEmpty {
            Text(text)
                .font(.caption)
                .padding(.top, 2)
        }
    }

    private var formattedTime: String {
        guard let dateString = message.createdAt else { return "" }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else { return "" }
            return formatDate(date)
        }
        return formatDate(date)
    }

    private func formatDate(_ date: Date) -> String {
        let timeFormatter = DateFormatter()
        // Always show month/day and time
        timeFormatter.dateFormat = "MMM d, h:mm a"
        return timeFormatter.string(from: date)
    }
}

// MARK: - Authenticated Media (sends JWT with image/video requests)

struct AuthenticatedImage: View {
    let path: String
    var maxWidth: CGFloat = 240
    var maxHeight: CGFloat = 240
    var cornerRadius: CGFloat = 12

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else if failed {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .frame(width: 60, height: 60)
            } else {
                ProgressView()
                    .frame(width: 60, height: 60)
            }
        }
        .task(id: path) {
            await load()
        }
    }

    private func load() async {
        guard let url = URL(string: "\(APIClient.shared.baseURL)/api/uploads/\(path)") else {
            failed = true
            return
        }

        var request = URLRequest(url: url)
        if let token = KeychainManager.bearerToken {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let uiImage = UIImage(data: data) {
                self.image = uiImage
            } else {
                failed = true
            }
        } catch {
            failed = true
        }
    }
}

struct AuthenticatedVideoPlayer: View {
    let path: String
    var width: CGFloat = 240
    var height: CGFloat = 180
    var cornerRadius: CGFloat = 12

    @State private var localURL: URL?
    @State private var failed = false

    var body: some View {
        Group {
            if let localURL {
                VideoPlayer(player: AVPlayer(url: localURL))
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else if failed {
                Image(systemName: "video.slash")
                    .foregroundStyle(.secondary)
                    .frame(width: 60, height: 60)
            } else {
                ProgressView()
                    .frame(width: 60, height: 60)
            }
        }
        .task(id: path) {
            await load()
        }
    }

    private func load() async {
        guard let url = URL(string: "\(APIClient.shared.baseURL)/api/uploads/\(path)") else {
            failed = true
            return
        }

        var request = URLRequest(url: url)
        if let token = KeychainManager.bearerToken {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mp4")
            try data.write(to: tempFile)
            self.localURL = tempFile
        } catch {
            failed = true
        }
    }
}
