import Foundation

@MainActor
@Observable
final class ChatViewModel {
    var rooms: [ChatRoom] = []
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
    var roomToEdit: ChatRoom?
    var roomToDelete: ChatRoom?

    // Media upload
    var isUploadingMedia = false

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
        }

        selectedRoom = room
        socketManager?.joinRoom(room.id)
        await loadMessages(for: room.id)
    }

    func loadMessages(for roomId: Int) async {
        isLoadingMessages = true

        do {
            messages = try await ChatAPIService.getMessages(roomId: roomId)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMessages = false
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
        socketManager?.onNewMessage = { [weak self] message in
            guard let self else { return }
            if message.roomId == self.selectedRoom?.id {
                if !self.messages.contains(where: { $0.id == message.id }) {
                    self.messages.append(message)
                }
            }
        }
        socketManager?.onUserTyping = { [weak self] roomId, user, isTyping in
            guard let self, roomId == self.selectedRoom?.id else { return }
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
        }
    }
}
