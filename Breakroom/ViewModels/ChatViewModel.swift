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

    var socketManager: ChatSocketManager?
    private var typingStopTask: Task<Void, Never>?

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

        // Stop typing indicator
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
