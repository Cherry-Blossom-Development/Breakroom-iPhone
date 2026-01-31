import Foundation
import SocketIO

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

    private var manager: SocketIO.SocketManager?
    private var socket: SocketIOClient?

    func connect() {
        guard let token = KeychainManager.token else { return }
        guard connectionState == .disconnected else { return }

        connectionState = .connecting

        let url = URL(string: "https://www.prosaurus.com")!
        manager = SocketIO.SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .forceWebsockets(true),
            .reconnects(true),
            .reconnectAttempts(10),
            .reconnectWait(1),
            .connectParams(["token": token])
        ])

        guard let manager else { return }
        socket = manager.defaultSocket

        setupEventHandlers()
        socket?.connect()
    }

    func disconnect() {
        socket?.disconnect()
        socket = nil
        manager?.disconnect()
        manager = nil
        connectionState = .disconnected
    }

    func joinRoom(_ roomId: Int) {
        socket?.emit("join_room", roomId)
    }

    func leaveRoom(_ roomId: Int) {
        socket?.emit("leave_room", roomId)
    }

    func sendMessage(roomId: Int, message: String) {
        socket?.emit("send_message", ["roomId": roomId, "message": message])
    }

    func startTyping(roomId: Int) {
        socket?.emit("typing_start", roomId)
    }

    func stopTyping(roomId: Int) {
        socket?.emit("typing_stop", roomId)
    }

    // MARK: - Event Handlers

    private func setupEventHandlers() {
        socket?.on(clientEvent: .connect) { [weak self] _, _ in
            Task { @MainActor in
                self?.connectionState = .connected
                print("[Socket] Connected")
            }
        }

        socket?.on(clientEvent: .disconnect) { [weak self] _, _ in
            Task { @MainActor in
                self?.connectionState = .disconnected
                print("[Socket] Disconnected")
            }
        }

        socket?.on(clientEvent: .reconnect) { _, _ in
            print("[Socket] Reconnecting...")
        }

        socket?.on(clientEvent: .error) { data, _ in
            print("[Socket] Error:", data)
        }

        socket?.on("new_message") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let messageDict = dict["message"] as? [String: Any],
                  let id = messageDict["id"] as? Int else {
                return
            }

            let message = ChatMessage(
                id: id,
                roomId: dict["roomId"] as? Int,
                userId: messageDict["user_id"] as? Int,
                handle: messageDict["handle"] as? String,
                message: messageDict["message"] as? String,
                imagePath: messageDict["image_path"] as? String,
                videoPath: messageDict["video_path"] as? String,
                createdAt: messageDict["created_at"] as? String
            )

            Task { @MainActor in
                self?.onNewMessage?(message)
            }
        }

        socket?.on("user_typing") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let roomId = dict["roomId"] as? Int,
                  let user = dict["user"] as? String else {
                return
            }

            Task { @MainActor in
                self?.onUserTyping?(roomId, user, true)
            }
        }

        socket?.on("user_stopped_typing") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let roomId = dict["roomId"] as? Int,
                  let user = dict["user"] as? String else {
                return
            }

            Task { @MainActor in
                self?.onUserTyping?(roomId, user, false)
            }
        }
    }
}
