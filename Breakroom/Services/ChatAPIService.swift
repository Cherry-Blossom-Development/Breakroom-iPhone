import Foundation

enum ChatAPIService {
    static func getRooms() async throws -> [ChatRoom] {
        try await APIClient.shared.request("/api/chat/rooms")
    }

    static func getMessages(roomId: Int, limit: Int = 50, before: Int? = nil) async throws -> [ChatMessage] {
        var path = "/api/chat/rooms/\(roomId)/messages?limit=\(limit)"
        if let before {
            path += "&before=\(before)"
        }
        return try await APIClient.shared.request(path)
    }

    static func sendMessage(roomId: Int, message: String) async throws -> ChatMessage {
        let body = SendMessageRequest(message: message)
        return try await APIClient.shared.request(
            "/api/chat/rooms/\(roomId)/messages",
            method: "POST",
            body: body
        )
    }

    static func createRoom(name: String, description: String?) async throws -> ChatRoom {
        let body = CreateRoomRequest(name: name, description: description)
        return try await APIClient.shared.request(
            "/api/chat/rooms",
            method: "POST",
            body: body
        )
    }
}
