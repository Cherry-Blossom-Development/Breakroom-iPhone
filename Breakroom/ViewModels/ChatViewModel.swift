import Foundation
import SwiftUI

@MainActor
@Observable
final class ChatViewModel {
    var rooms: [ChatRoom] = []
    var discoverableRooms: [ChatRoom] = []
    var messages: [ChatMessage] = []
    var selectedRoom: ChatRoom?
    var isLoadingRooms = false
    var isLoadingMessages = false
    var errorMessage: String?
    var messageText = ""
    var typingUsers: [String] = []

    // Room management
    var pendingInvites: [ChatInvite] = []
    var canCreateRoomPermission = false
    var showCreateRoom = false
    var showEditRoom = false
    var showInviteUsers = false
    var showDeleteConfirmation = false
    var showAddRoom = false
    var roomToEdit: ChatRoom?
    var roomToDelete: ChatRoom?
    var roomToLeave: ChatRoom?
    var showLeaveConfirmation = false

    // Media upload
    var isUploadingMedia = false

    // Direct Messages
    var dms: [ChatDm] = []
    var dmSearchQuery = ""
    var dmSearchResults: [User] = []
    var allUsersForDm: [User] = []
    var isStartingDm = false
    var selectedDm: ChatDm?

    // Pagination state
    var hasOlderMessages = false
    var oldestMessageDate: String?
    var isLoadingOlderMessages = false

    var socketManager: ChatSocketManager?
    private var typingStopTask: Task<Void, Never>?

    var currentUserId: Int? {
        guard let storedId = KeychainManager.get(.userId) else { return nil }
        return Int(storedId)
    }

    func isRoomOwner(_ room: ChatRoom) -> Bool {
        guard let userId = currentUserId else { return false }
        return room.ownerId == userId
    }

    // MARK: - Rooms

    func loadRooms() async {
        isLoadingRooms = true
        errorMessage = nil

        do {
            rooms = try await ChatAPIService.getRooms()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingRooms = false
    }

    func createRoom(name: String, description: String?, inviteUserIds: [Int]) async {
        do {
            let room = try await ChatAPIService.createRoom(name: name, description: description)
            rooms.append(room)

            for userId in inviteUserIds {
                try? await ChatAPIService.inviteUser(roomId: room.id, userId: userId)
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateRoom(id: Int, name: String, description: String?) async {
        do {
            let updated = try await ChatAPIService.updateRoom(id: id, name: name, description: description)
            if let index = rooms.firstIndex(where: { $0.id == id }) {
                rooms[index] = updated
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteRoom(_ room: ChatRoom) async {
        do {
            try await ChatAPIService.deleteRoom(id: room.id)
            rooms.removeAll { $0.id == room.id }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func leaveRoom(_ room: ChatRoom) async {
        do {
            try await ChatAPIService.leaveRoom(id: room.id)
            rooms.removeAll { $0.id == room.id }
            // If leaving the currently selected room, clear selection
            if selectedRoom?.id == room.id {
                socketManager?.leaveRoom(room.id)
                selectedRoom = nil
                messages = []
                typingUsers = []
                // Auto-select first remaining room
                if let first = rooms.first {
                    await selectRoom(first)
                }
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Discoverable Rooms

    func loadDiscoverableRooms() async {
        do {
            discoverableRooms = try await ChatAPIService.getDiscoverableRooms()
        } catch {
            // Silently fail - discoverable rooms are supplementary
        }
    }

    func joinDiscoverableRoom(_ room: ChatRoom) async {
        do {
            let joinedRoom = try await ChatAPIService.joinRoom(id: room.id)
            discoverableRooms.removeAll { $0.id == room.id }
            if !rooms.contains(where: { $0.id == joinedRoom.id }) {
                rooms.append(joinedRoom)
            }
            showAddRoom = false
            await selectRoom(joinedRoom)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Invites

    func loadInvites() async {
        do {
            pendingInvites = try await ChatAPIService.getInvites()
        } catch {
            // Silently fail — invites are supplementary
        }
    }

    func acceptInvite(_ invite: ChatInvite) async {
        do {
            let room = try await ChatAPIService.acceptInvite(roomId: invite.roomId)
            pendingInvites.removeAll { $0.roomId == invite.roomId }
            if !rooms.contains(where: { $0.id == room.id }) {
                rooms.append(room)
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declineInvite(_ invite: ChatInvite) async {
        do {
            try await ChatAPIService.declineInvite(roomId: invite.roomId)
            pendingInvites.removeAll { $0.roomId == invite.roomId }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Permissions

    func checkPermissions() async {
        do {
            canCreateRoomPermission = try await ChatAPIService.canCreateRoom()
        } catch {
            canCreateRoomPermission = false
        }
    }

    // MARK: - Messages & Room Selection

    func selectRoom(_ room: ChatRoom) async {
        if let previous = selectedRoom {
            socketManager?.leaveRoom(previous.id)
            socketManager?.removeListeners(roomId: previous.id)
        }

        selectedRoom = room
        hasOlderMessages = false
        oldestMessageDate = nil
        socketManager?.joinRoom(room.id)
        registerSocketListeners(for: room.id)
        await loadMessages(for: room.id)
    }

    func loadMessages(for roomId: Int) async {
        isLoadingMessages = true

        do {
            let (msgs, hasMore) = try await ChatAPIService.getMessages(roomId: roomId)
            messages = msgs
            hasOlderMessages = hasMore
            oldestMessageDate = msgs.first?.createdAt
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMessages = false
    }

    func loadOlderMessages() async {
        guard let roomId = selectedRoom?.id,
              let oldest = oldestMessageDate,
              hasOlderMessages,
              !isLoadingOlderMessages else { return }

        isLoadingOlderMessages = true

        do {
            let (olderMsgs, hasMore) = try await ChatAPIService.getMessages(roomId: roomId, before: oldest)
            // Prepend older messages, avoiding duplicates
            let existingIds = Set(messages.map(\.id))
            let newMessages = olderMsgs.filter { !existingIds.contains($0.id) }
            if !newMessages.isEmpty {
                messages = newMessages + messages
                oldestMessageDate = newMessages.first?.createdAt
            }
            hasOlderMessages = hasMore
        } catch {
            // Silently fail - user can try scrolling again
        }

        isLoadingOlderMessages = false
    }

    func sendMessage() async {
        guard let room = selectedRoom, !messageText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }

        let text = messageText
        messageText = ""

        stopTyping()

        if socketManager?.connectionState == .connected {
            socketManager?.sendMessage(roomId: room.id, message: text)
        } else {
            do {
                let message = try await ChatAPIService.sendMessage(roomId: room.id, message: text)
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                }
            } catch {
                messageText = text
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Media Upload

    func uploadImage(data: Data, filename: String) async {
        guard let room = selectedRoom else { return }
        isUploadingMedia = true
        do {
            let message = try await ChatAPIService.uploadImage(roomId: room.id, imageData: data, filename: filename)
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isUploadingMedia = false
    }

    func uploadVideo(data: Data, filename: String) async {
        guard let room = selectedRoom else { return }
        isUploadingMedia = true
        do {
            let message = try await ChatAPIService.uploadVideo(roomId: room.id, videoData: data, filename: filename)
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isUploadingMedia = false
    }

    // MARK: - Edit & Delete Messages

    func editMessage(_ messageId: Int, newText: String) async {
        guard let room = selectedRoom else { return }

        do {
            let updated = try await ChatAPIService.editMessage(roomId: room.id, messageId: messageId, message: newText)
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index] = updated
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteMessage(_ messageId: Int) async {
        guard let room = selectedRoom else { return }

        do {
            try await ChatAPIService.deleteMessage(roomId: room.id, messageId: messageId)
            messages.removeAll { $0.id == messageId }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Typing

    func handleTypingChanged() {
        guard let room = selectedRoom, !messageText.isEmpty else { return }
        socketManager?.startTyping(roomId: room.id)
        typingStopTask?.cancel()
        typingStopTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            stopTyping()
        }
    }

    private func stopTyping() {
        typingStopTask?.cancel()
        typingStopTask = nil
        if let room = selectedRoom {
            socketManager?.stopTyping(roomId: room.id)
        }
    }

    // MARK: - Socket

    func connectSocket() {
        // Initial connection - listeners are registered in selectRoom
    }

    private func registerSocketListeners(for roomId: Int) {
        socketManager?.addMessageListener(roomId: roomId) { [weak self] message in
            guard let self else { return }
            if !self.messages.contains(where: { $0.id == message.id }) {
                self.messages.append(message)
                self.announceNewMessage(message)
            }
        }
        socketManager?.addEditListener(roomId: roomId) { [weak self] message in
            guard let self else { return }
            if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                self.messages[index] = message
            }
        }
        socketManager?.addDeleteListener(roomId: roomId) { [weak self] messageId in
            guard let self else { return }
            self.messages.removeAll { $0.id == messageId }
        }
        socketManager?.addTypingListener(roomId: roomId) { [weak self] user, isTyping in
            guard let self else { return }
            if isTyping {
                if !self.typingUsers.contains(user) {
                    self.typingUsers.append(user)
                }
            } else {
                self.typingUsers.removeAll { $0 == user }
            }
        }
    }

    func disconnectSocket() {
        if let room = selectedRoom {
            socketManager?.leaveRoom(room.id)
            socketManager?.removeListeners(roomId: room.id)
        }
    }

    private func announceNewMessage(_ message: ChatMessage) {
        // Don't announce our own messages
        if message.userId == currentUserId {
            return
        }

        let sender = message.handle ?? "Someone"
        var announcement = "New message from \(sender)"

        if let text = message.message, !text.isEmpty {
            // Truncate long messages for the announcement
            let preview = text.count > 50 ? String(text.prefix(50)) + "..." : text
            announcement += ": \(preview)"
        } else if message.imagePath != nil {
            announcement += ": sent an image"
        } else if message.videoPath != nil {
            announcement += ": sent a video"
        }

        AccessibilityNotification.Announcement(announcement).post()
    }

    // MARK: - Direct Messages

    func loadDms() async {
        do {
            dms = try await ChatAPIService.getDms()
        } catch {
            // Silently fail - DMs are supplementary
        }
    }

    func loadAllUsersForDmSearch() async {
        do {
            allUsersForDm = try await ChatAPIService.getAllUsers()
            // Filter out current user
            if let userId = currentUserId {
                allUsersForDm.removeAll { $0.id == userId }
            }
        } catch {
            // Silently fail
        }
    }

    func updateDmSearchQuery(_ query: String) {
        dmSearchQuery = query
        if query.isEmpty {
            dmSearchResults = []
        } else {
            let lowercased = query.lowercased()
            dmSearchResults = allUsersForDm.filter { user in
                user.handle.lowercased().contains(lowercased) ||
                user.displayName.lowercased().contains(lowercased)
            }
        }
    }

    func startDm(with user: User) async -> DmRoomInfo? {
        isStartingDm = true
        defer { isStartingDm = false }

        do {
            let roomInfo = try await ChatAPIService.startDm(userId: user.id)
            // Clear search
            dmSearchQuery = ""
            dmSearchResults = []
            // Reload DMs to include the new/existing one
            await loadDms()
            return roomInfo
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func selectDm(_ dm: ChatDm) async {
        if let previous = selectedRoom {
            socketManager?.leaveRoom(previous.id)
            socketManager?.removeListeners(roomId: previous.id)
        }

        // Create a pseudo ChatRoom for DM display
        selectedDm = dm
        selectedRoom = nil  // Clear room selection since we're in a DM
        hasOlderMessages = false
        oldestMessageDate = nil
        socketManager?.joinRoom(dm.id)
        registerSocketListeners(for: dm.id)
        await loadMessages(for: dm.id)
    }

    /// Check if current room is a DM
    var isDmSelected: Bool {
        selectedDm != nil
    }

    /// Get the current room ID (works for both regular rooms and DMs)
    var currentRoomId: Int? {
        selectedRoom?.id ?? selectedDm?.id
    }
}
