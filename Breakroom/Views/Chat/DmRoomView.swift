import SwiftUI
import PhotosUI

struct DmRoomView: View {
    let dm: ChatDm
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

                        // Bottom anchor for scrolling
                        Color.clear
                            .frame(height: 1)
                            .id("bottomAnchor")
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
                .onChange(of: chatViewModel.isLoadingMessages) { oldValue, newValue in
                    // Scroll to bottom when initial load completes
                    if oldValue == true && newValue == false && !chatViewModel.messages.isEmpty {
                        Task {
                            try? await Task.sleep(for: .milliseconds(100))
                            withAnimation {
                                proxy.scrollTo("bottomAnchor", anchor: .bottom)
                            }
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
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Uploading media")
            }

            // Message input
            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhoto, matching: .any(of: [.images, .videos])) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .disabled(chatViewModel.isUploadingMedia)
                .accessibilityLabel("Attach photo or video")

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
                    .accessibilityLabel("Message to @\(dm.partnerHandle)")

                Button {
                    Task { await sendDmMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(chatViewModel.messageText.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("sendButton")
                .accessibilityLabel("Send message")
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
                        .accessibilityHidden(true)
                    Text("@\(dm.partnerHandle)")
                        .font(.headline)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Direct message with @\(dm.partnerHandle). \(socketManager.connectionState == .connected ? "Connected" : "Disconnected")")
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
            await chatViewModel.selectDm(dm)
            await badgeStore.markRoomRead(dm.id)
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

    private func sendDmMessage() async {
        guard !chatViewModel.messageText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }

        let text = chatViewModel.messageText
        chatViewModel.messageText = ""

        // Use socket if connected, otherwise fall back to HTTP
        if socketManager.connectionState == .connected {
            socketManager.sendMessage(roomId: dm.id, message: text)
        } else {
            do {
                let message = try await ChatAPIService.sendMessage(roomId: dm.id, message: text)
                if !chatViewModel.messages.contains(where: { $0.id == message.id }) {
                    chatViewModel.messages.append(message)
                }
            } catch {
                chatViewModel.messageText = text
                chatViewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private func handlePickedMedia(_ item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self) {
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                await uploadDmVideo(data: data)
            } else {
                await uploadDmImage(data: data)
            }
        }
    }

    private func uploadDmImage(data: Data) async {
        chatViewModel.isUploadingMedia = true
        do {
            let message = try await ChatAPIService.uploadImage(roomId: dm.id, imageData: data, filename: "image.jpg")
            if !chatViewModel.messages.contains(where: { $0.id == message.id }) {
                chatViewModel.messages.append(message)
            }
        } catch let error as APIError {
            chatViewModel.errorMessage = error.errorDescription
        } catch {
            chatViewModel.errorMessage = error.localizedDescription
        }
        chatViewModel.isUploadingMedia = false
    }

    private func uploadDmVideo(data: Data) async {
        chatViewModel.isUploadingMedia = true
        do {
            let message = try await ChatAPIService.uploadVideo(roomId: dm.id, videoData: data, filename: "video.mp4")
            if !chatViewModel.messages.contains(where: { $0.id == message.id }) {
                chatViewModel.messages.append(message)
            }
        } catch let error as APIError {
            chatViewModel.errorMessage = error.errorDescription
        } catch {
            chatViewModel.errorMessage = error.localizedDescription
        }
        chatViewModel.isUploadingMedia = false
    }
}
