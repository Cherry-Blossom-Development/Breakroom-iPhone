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

    // Multiple listeners per room - keyed by room ID
    private var messageListeners: [Int: [@MainActor (ChatMessage) -> Void]] = [:]
    private var editListeners: [Int: [@MainActor (ChatMessage) -> Void]] = [:]
    private var deleteListeners: [Int: [@MainActor (Int) -> Void]] = [:]
    private var typingListeners: [Int: [@MainActor (String, Bool) -> Void]] = [:]

    // Badge update handlers (set by BadgeStore)
    var onChatBadgeUpdate: ((Int) -> Void)?
    var onFriendBadgeUpdate: (() -> Void)?
    var onBlogBadgeUpdate: ((Int) -> Void)?

    private var manager: SocketIO.SocketManager?
    private var socket: SocketIOClient?

    // MARK: - Listener Registration

    /// Register a listener for new messages in a room. Returns an ID to use for unregistering.
    func addMessageListener(roomId: Int, handler: @escaping @MainActor (ChatMessage) -> Void) {
        if messageListeners[roomId] == nil {
            messageListeners[roomId] = []
        }
        messageListeners[roomId]?.append(handler)
    }

    func addEditListener(roomId: Int, handler: @escaping @MainActor (ChatMessage) -> Void) {
        if editListeners[roomId] == nil {
            editListeners[roomId] = []
        }
        editListeners[roomId]?.append(handler)
    }

    func addDeleteListener(roomId: Int, handler: @escaping @MainActor (Int) -> Void) {
        if deleteListeners[roomId] == nil {
            deleteListeners[roomId] = []
        }
        deleteListeners[roomId]?.append(handler)
    }

    func addTypingListener(roomId: Int, handler: @escaping @MainActor (String, Bool) -> Void) {
        if typingListeners[roomId] == nil {
            typingListeners[roomId] = []
        }
        typingListeners[roomId]?.append(handler)
    }

    /// Remove all listeners for a room (called when widget disappears)
    func removeListeners(roomId: Int) {
        messageListeners.removeValue(forKey: roomId)
        editListeners.removeValue(forKey: roomId)
        deleteListeners.removeValue(forKey: roomId)
        typingListeners.removeValue(forKey: roomId)
    }

    func connect() {
        guard let token = KeychainManager.token else { return }
        guard connectionState == .disconnected else { return }

        connectionState = .connecting

        let url = URL(string: Config.baseURL)!
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
                #if DEBUG
                print("[Socket] Connected")
                #endif
            }
        }

        socket?.on(clientEvent: .disconnect) { [weak self] _, _ in
            Task { @MainActor in
                self?.connectionState = .disconnected
                #if DEBUG
                print("[Socket] Disconnected")
                #endif
            }
        }

        socket?.on(clientEvent: .reconnect) { _, _ in
            #if DEBUG
            print("[Socket] Reconnecting...")
            #endif
        }

        socket?.on(clientEvent: .error) { data, _ in
            #if DEBUG
            print("[Socket] Error:", data)
            #endif
        }

        socket?.on("new_message") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let messageDict = dict["message"] as? [String: Any],
                  let id = messageDict["id"] as? Int else {
                return
            }

            let roomId = dict["roomId"] as? Int
            let message = ChatMessage(
                id: id,
                roomId: roomId,
                userId: messageDict["user_id"] as? Int,
                handle: messageDict["handle"] as? String,
                message: messageDict["message"] as? String,
                imagePath: messageDict["image_path"] as? String,
                videoPath: messageDict["video_path"] as? String,
                createdAt: messageDict["created_at"] as? String
            )

            Task { @MainActor in
                guard let self = self, let roomId = roomId else { return }
                // Notify all listeners for this room
                if let listeners = self.messageListeners[roomId] {
                    for listener in listeners {
                        listener(message)
                    }
                }
            }
        }

        socket?.on("message_edited") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let roomId = dict["roomId"] as? Int,
                  let messageDict = dict["message"] as? [String: Any],
                  let id = messageDict["id"] as? Int else {
                return
            }

            let message = ChatMessage(
                id: id,
                roomId: roomId,
                userId: messageDict["user_id"] as? Int,
                handle: messageDict["handle"] as? String,
                message: messageDict["message"] as? String,
                imagePath: messageDict["image_path"] as? String,
                videoPath: messageDict["video_path"] as? String,
                createdAt: messageDict["created_at"] as? String
            )

            Task { @MainActor in
                guard let self = self else { return }
                if let listeners = self.editListeners[roomId] {
                    for listener in listeners {
                        listener(message)
                    }
                }
            }
        }

        socket?.on("message_deleted") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let roomId = dict["roomId"] as? Int,
                  let messageId = dict["messageId"] as? Int else {
                return
            }

            Task { @MainActor in
                guard let self = self else { return }
                if let listeners = self.deleteListeners[roomId] {
                    for listener in listeners {
                        listener(messageId)
                    }
                }
            }
        }

        socket?.on("user_typing") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let roomId = dict["roomId"] as? Int,
                  let user = dict["user"] as? String else {
                return
            }

            Task { @MainActor in
                guard let self = self else { return }
                if let listeners = self.typingListeners[roomId] {
                    for listener in listeners {
                        listener(user, true)
                    }
                }
            }
        }

        socket?.on("user_stopped_typing") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let roomId = dict["roomId"] as? Int,
                  let user = dict["user"] as? String else {
                return
            }

            Task { @MainActor in
                guard let self = self else { return }
                if let listeners = self.typingListeners[roomId] {
                    for listener in listeners {
                        listener(user, false)
                    }
                }
            }
        }

        // Badge update events
        socket?.on("chat_badge_update") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let roomId = dict["roomId"] as? Int else {
                return
            }
            Task { @MainActor in
                self?.onChatBadgeUpdate?(roomId)
            }
        }

        socket?.on("friend_badge_update") { [weak self] _, _ in
            Task { @MainActor in
                self?.onFriendBadgeUpdate?()
            }
        }

        socket?.on("blog_badge_update") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let postId = dict["postId"] as? Int else {
                return
            }
            Task { @MainActor in
                self?.onBlogBadgeUpdate?(postId)
            }
        }
    }
}
