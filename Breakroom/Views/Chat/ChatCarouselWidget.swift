import SwiftUI
import PhotosUI
import os.log

private let logger = Logger(subsystem: "com.cherryblossomdev.Breakroom", category: "ChatCarousel")

/// A carousel widget that displays chat rooms one at a time with left/right navigation.
/// Rooms are sorted by last message time (oldest left, newest right).
/// Starts on the rightmost (most recently active) room.
struct ChatCarouselWidget: View {
    @Environment(ChatSocketManager.self) private var socketManager

    // State
    @State private var rooms: [RecentRoomMessage] = []
    @State private var currentIndex: Int = 0
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = true
    @State private var isLoadingMessages = false
    @State private var isSending = false
    @State private var messageText = ""
    @State private var error: String?
    @State private var rightGlowing = false
    @State private var hasLoadedRooms = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingMedia = false

    // Navigation callback
    var onOpenRoom: ((Int) -> Void)?

    private var currentRoom: RecentRoomMessage? {
        guard currentIndex >= 0 && currentIndex < rooms.count else { return nil }
        return rooms[currentIndex]
    }

    private var canGoLeft: Bool { currentIndex > 0 }
    private var canGoRight: Bool { currentIndex < rooms.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if let error {
                errorView(error)
            } else if rooms.isEmpty {
                emptyView
            } else {
                carouselView
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            if !hasLoadedRooms {
                await loadRooms()
            }
        }
        .onDisappear {
            cleanup()
        }
    }

    // MARK: - Main Carousel View

    private var carouselView: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            messagesView
            Divider()
            inputView
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            // Left navigation - using onTapGesture instead of Button
            Image(systemName: "chevron.left")
                .font(.caption.weight(.semibold))
                .foregroundStyle(canGoLeft ? Color.primary : Color.secondary.opacity(0.3))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .onTapGesture {
                    if canGoLeft {
                        navigateLeft()
                    }
                }

            Spacer()

            if let room = currentRoom {
                Text("# \(room.roomName)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .onTapGesture {
                        onOpenRoom?(room.roomId)
                    }
            }

            Spacer()

            Text("\(currentIndex + 1) / \(rooms.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Right navigation - using onTapGesture instead of Button
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(canGoRight ? Color.primary : Color.secondary.opacity(0.3))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(rightGlowing ? Color.yellow.opacity(0.4) : Color.clear)
                )
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .onTapGesture {
                    if canGoRight {
                        navigateRight()
                    }
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Navigation

    private func navigateLeft() {
        let newIndex = currentIndex - 1
        guard newIndex >= 0 else { return }
        logger.debug("navigateLeft: \(currentIndex) -> \(newIndex)")
        currentIndex = newIndex
        let roomId = rooms[newIndex].roomId
        Task {
            await loadMessages(for: roomId)
        }
    }

    private func navigateRight() {
        let newIndex = currentIndex + 1
        guard newIndex < rooms.count else { return }
        logger.debug("navigateRight: \(currentIndex) -> \(newIndex)")
        currentIndex = newIndex
        rightGlowing = false
        let roomId = rooms[newIndex].roomId
        Task {
            await loadMessages(for: roomId)
        }
    }

    // MARK: - Messages View

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if isLoadingMessages {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else if messages.isEmpty {
                    Text("No messages yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(messages) { msg in
                            messageRow(msg)
                                .id(msg.id)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                            .onAppear {
                                if !isLoadingMessages && !messages.isEmpty {
                                    proxy.scrollTo("bottom", anchor: .bottom)
                                }
                            }
                    }
                }
            }
            .defaultScrollAnchor(.bottom)
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 250)
            .onChange(of: isLoadingMessages) { old, new in
                if old && !new && !messages.isEmpty {
                    for delay in [0, 100, 300] {
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: messages.count) {
                if !messages.isEmpty {
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
    }

    private func messageRow(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(message.handle ?? "Unknown")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                if let t = message.createdAt {
                    Text(formatTime(t))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if let text = message.message, !text.isEmpty {
                Text(text).font(.caption)
            }
            Divider().padding(.top, 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    // MARK: - Input View

    private var inputView: some View {
        HStack(spacing: 12) {
            // Media picker button
            PhotosPicker(selection: $selectedPhoto, matching: .any(of: [.images, .videos])) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .disabled(isUploadingMedia)

            TextField("Message", text: $messageText)
                .textFieldStyle(.plain)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            // Send button
            Button {
                Task { await sendMessage() }
            } label: {
                Group {
                    if isSending || isUploadingMedia {
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
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .onChange(of: selectedPhoto) {
            guard let item = selectedPhoto else { return }
            selectedPhoto = nil
            guard let roomId = currentRoom?.roomId else { return }
            Task { await handlePickedMedia(item, roomId: roomId) }
        }
    }

    // MARK: - Loading Views

    private var loadingView: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Loading rooms...").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle").font(.title2).foregroundStyle(.red)
            Text(msg).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Retry") {
                hasLoadedRooms = false
                Task { await loadRooms() }
            }.font(.caption).buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right").font(.title).foregroundStyle(.secondary)
            Text("No chat rooms yet").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }

    // MARK: - Data Loading

    private func loadRooms() async {
        logger.debug("loadRooms: starting")
        isLoading = true
        error = nil
        do {
            rooms = try await ChatAPIService.getRecentRooms()
            if !rooms.isEmpty {
                currentIndex = rooms.count - 1
                logger.debug("loadRooms: loaded \(rooms.count) rooms, currentIndex=\(currentIndex)")
                await loadMessages(for: rooms[currentIndex].roomId)
            }
            hasLoadedRooms = true
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
        } catch {}
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
            messageText = text
        }
        isSending = false
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

    // MARK: - Socket

    private func joinAllRooms() {
        for room in rooms {
            socketManager.joinRoom(room.roomId)
            socketManager.addMessageListener(roomId: room.roomId) { msg in
                handleNewMessage(msg, roomId: room.roomId)
            }
            socketManager.addEditListener(roomId: room.roomId) { msg in
                if currentRoom?.roomId == room.roomId,
                   let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                    messages[idx] = msg
                }
            }
            socketManager.addDeleteListener(roomId: room.roomId) { msgId in
                if currentRoom?.roomId == room.roomId {
                    messages.removeAll { $0.id == msgId }
                }
            }
        }
    }

    private func handleNewMessage(_ message: ChatMessage, roomId: Int) {
        guard let idx = rooms.firstIndex(where: { $0.roomId == roomId }) else { return }
        rooms[idx].message = message.message
        rooms[idx].handle = message.handle ?? rooms[idx].handle
        rooms[idx].createdAt = message.createdAt ?? rooms[idx].createdAt

        if currentRoom?.roomId == roomId {
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
        } else {
            triggerGlow()
        }
    }

    private func triggerGlow() {
        withAnimation(.easeIn(duration: 0.2)) { rightGlowing = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.5)) { rightGlowing = false }
        }
    }

    private func cleanup() {
        for room in rooms {
            socketManager.leaveRoom(room.roomId)
            socketManager.removeListeners(roomId: room.roomId)
        }
    }

    // MARK: - Helpers

    private func formatTime(_ iso: String) -> String {
        guard let date = parseDate(iso) else { return "" }
        let f = DateFormatter()
        f.dateFormat = Calendar.current.isDateInToday(date) ? "h:mm a" : "MMM d, h:mm a"
        return f.string(from: date)
    }

    private func parseDate(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? {
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: s)
        }()
    }
}
