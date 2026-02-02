import SwiftUI
import PhotosUI
import AVKit

struct ChatWidget: View {
    let block: BreakroomBlock
    @Environment(ChatSocketManager.self) private var socketManager
    @State private var messages: [ChatMessage] = []
    @State private var messageText = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var error: String?
    @State private var typingUsers: [String] = []
    @State private var typingStopTask: Task<Void, Never>?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingMedia: Bool = false

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
            socketManager.joinRoom(roomId)
            socketManager.onNewMessage = { message in
                if message.roomId == roomId || message.roomId == nil {
                    if !messages.contains(where: { $0.id == message.id }) {
                        messages.append(message)
                    }
                }
            }
            socketManager.onUserTyping = { eventRoomId, user, isTyping in
                guard eventRoomId == roomId else { return }
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
                        ForEach(messages) { message in
                            ChatWidgetMessageRow(message: message)
                                .id(message.id)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 300)
            .defaultScrollAnchor(.bottom)
            .onChange(of: messages.count) {
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func messageInput(roomId: Int) -> some View {
        HStack(spacing: 8) {
            PhotosPicker(selection: $selectedPhoto, matching: .any(of: [.images, .videos])) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .disabled(isUploadingMedia)

            TextField("Message", text: $messageText)
                .textFieldStyle(.plain)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
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

            Button {
                Task { await sendMessage(roomId: roomId) }
            } label: {
                if isSending {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                }
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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
        do {
            messages = try await ChatAPIService.getMessages(roomId: roomId, limit: 30)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
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
}

// MARK: - Message Row (compact widget style, matching Android)

struct ChatWidgetMessageRow: View {
    let message: ChatMessage

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
            Text(message.handle ?? "Unknown")
                .font(.caption2)
                .fontWeight(.semibold)
            Spacer()
            Text(formattedTime)
                .font(.caption2)
                .foregroundStyle(.secondary)
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
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()

        if calendar.isDateInToday(date) {
            timeFormatter.dateFormat = "h:mm a"
        } else {
            timeFormatter.dateFormat = "M/d h:mm a"
        }

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
