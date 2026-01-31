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

    private let socketManager = ChatSocketManager()

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
            socketManager.leaveRoom(previous.id)
        }

        selectedRoom = room
        socketManager.joinRoom(room.id)
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

        do {
            let message = try await ChatAPIService.sendMessage(roomId: room.id, message: text)
            messages.append(message)
        } catch {
            messageText = text
            errorMessage = error.localizedDescription
        }
    }

    func connectSocket() {
        socketManager.onNewMessage = { [weak self] message in
            guard let self else { return }
            if message.roomId == self.selectedRoom?.id {
                self.messages.append(message)
            }
        }
        socketManager.connect()
    }

    func disconnectSocket() {
        if let room = selectedRoom {
            socketManager.leaveRoom(room.id)
        }
        socketManager.disconnect()
    }
}
