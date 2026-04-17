import SwiftUI
import PhotosUI

struct ChatRoomView: View {
    let room: ChatRoom
    @Bindable var chatViewModel: ChatViewModel
    @Environment(ChatSocketManager.self) private var socketManager
    @Environment(BadgeStore.self) private var badgeStore

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var suppressScrollToBottom = false
    @State private var messageToFlag: ChatMessage?
    @State private var messageToEdit: ChatMessage?
    @State private var editedMessageText = ""
    @State private var showDeleteConfirmation = false
    @State private var messageToDelete: ChatMessage?
    @State private var showBlockConfirmation = false
    @State private var userToBlock: (id: Int, handle: String)?

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        // Loading indicator at top when fetching older messages
                        if chatViewModel.isLoadingOlderMessages {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading older messages...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }

                        // Sentinel view to detect scroll to top
                        if chatViewModel.hasOlderMessages && !chatViewModel.isLoadingOlderMessages {
                            Color.clear
                                .frame(height: 1)
                                .id("topSentinel")
                                .onAppear {
                                    suppressScrollToBottom = true
                                    Task { await chatViewModel.loadOlderMessages() }
                                }
                        }

                        ForEach(chatViewModel.messages) { message in
                            MessageBubble(
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
                    .padding()
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: chatViewModel.messages.count) {
                    if suppressScrollToBottom {
                        suppressScrollToBottom = false
                    } else if let lastMessage = chatViewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            if !chatViewModel.typingUsers.isEmpty {
                HStack {
                    Text(chatViewModel.typingUsers.joined(separator: ", ")
                         + (chatViewModel.typingUsers.count == 1 ? " is" : " are")
                         + " typing...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .italic()
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 2)
            }

            Divider()

            // Upload progress
            if chatViewModel.isUploadingMedia {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Uploading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            // Message input
            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhoto, matching: .any(of: [.images, .videos])) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .disabled(chatViewModel.isUploadingMedia)

                TextField("Message", text: $chatViewModel.messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(.fill.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .onChange(of: chatViewModel.messageText) {
                        chatViewModel.handleTypingChanged()
                    }
                    .accessibilityIdentifier("messageInput")

                Button {
                    Task { await chatViewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(chatViewModel.messageText.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("sendButton")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(socketManager.connectionState == .connected ? .green : .red)
                        .frame(width: 8, height: 8)
                    VStack(spacing: 0) {
                        Text("# \(room.name)")
                            .font(.headline)
                            .lineLimit(1)
                        if let desc = room.description, !desc.isEmpty {
                            Text(desc)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .onChange(of: selectedPhoto) {
            guard let item = selectedPhoto else { return }
            selectedPhoto = nil
            Task { await handlePickedMedia(item) }
        }
        .task {
            await chatViewModel.selectRoom(room)
            await badgeStore.markRoomRead(room.id)
        }
        .sheet(item: $messageToFlag) { message in
            FlagDialogView(
                contentType: .chatMessage,
                contentId: message.id,
                onDismiss: {
                    messageToFlag = nil
                },
                onFlagged: {
                    // Optionally remove the message from view
                    chatViewModel.messages.removeAll { $0.id == message.id }
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
                        await chatViewModel.editMessage(message.id, newText: editedMessageText)
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
                        await chatViewModel.deleteMessage(message.id)
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
                        chatViewModel.messages.removeAll { $0.userId == user.id }
                        userToBlock = nil
                    }
                }
            }
        } message: {
            Text("They won't be able to see your content or contact you. You can unblock them from your Friends page.")
        }
        .navigationDestination(for: String.self) { handle in
            PublicProfileView(handle: handle)
        }
    }

    private func handlePickedMedia(_ item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self) {
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                await chatViewModel.uploadVideo(data: data, filename: "video.mp4")
            } else {
                await chatViewModel.uploadImage(data: data, filename: "image.jpg")
            }
        }
    }
}

struct MessageBubble: View {
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

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Header row with handle, timestamp, and menu
                HStack(spacing: 6) {
                    if !isCurrentUser, let handle = message.handle {
                        NavigationLink(value: handle) {
                            Text(handle)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                    Text(formattedTime)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    // Meatballs menu
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

                // Image attachment
                if let imagePath = message.imagePath, !imagePath.isEmpty {
                    AuthenticatedImage(path: imagePath)
                }

                // Video attachment
                if let videoPath = message.videoPath, !videoPath.isEmpty {
                    AuthenticatedVideoPlayer(path: videoPath)
                }

                // Text message
                if let text = message.message, !text.isEmpty {
                    Text(text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isCurrentUser ? Color.accentColor : Color(.systemGray5))
                        .foregroundStyle(isCurrentUser ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            if !isCurrentUser { Spacer(minLength: 60) }
        }
    }
}
