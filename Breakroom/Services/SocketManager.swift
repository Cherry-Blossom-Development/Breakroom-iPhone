import Foundation

// TODO: Replace with Socket.IO client once the package is added
// This is a placeholder that defines the interface.
// After adding the SocketIO Swift package, this will use SocketIOClient.

@MainActor
@Observable
final class ChatSocketManager {
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }

    private(set) var connectionState: ConnectionState = .disconnected
    var onNewMessage: (@MainActor (ChatMessage) -> Void)?
    var onUserTyping: (@MainActor (Int, String, Bool) -> Void)?

    func connect() {
        guard KeychainManager.token != nil else { return }
        connectionState = .connecting
        // TODO: Initialize Socket.IO connection with token auth
    }

    func disconnect() {
        connectionState = .disconnected
        // TODO: socket.disconnect()
    }

    func joinRoom(_ roomId: Int) {
        // TODO: socket.emit("join_room", roomId)
    }

    func leaveRoom(_ roomId: Int) {
        // TODO: socket.emit("leave_room", roomId)
    }

    func sendMessage(roomId: Int, message: String) {
        // TODO: socket.emit("send_message", ["roomId": roomId, "message": message])
    }

    func startTyping(roomId: Int) {
        // TODO: socket.emit("typing_start", roomId)
    }

    func stopTyping(roomId: Int) {
        // TODO: socket.emit("typing_stop", roomId)
    }
}
