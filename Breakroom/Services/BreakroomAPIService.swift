import Foundation

enum BreakroomAPIService {
    static func getLayout() async throws -> [BreakroomBlock] {
        let response: BreakroomLayoutResponse = try await APIClient.shared.request(
            "/api/breakroom/layout"
        )
        return response.blocks
    }

    static func addBlock(type: BlockType, title: String?, contentId: Int? = nil) async throws -> BreakroomBlock {
        let body = AddBlockRequest(blockType: type.rawValue, title: title, contentId: contentId, w: 2, h: 2)
        return try await APIClient.shared.request(
            "/api/breakroom/blocks",
            method: "POST",
            body: body
        )
    }

    static func removeBlock(id: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/breakroom/blocks/\(id)",
            method: "DELETE"
        )
    }

    static func getUpdates(limit: Int = 20) async throws -> [BreakroomUpdate] {
        let response: BreakroomUpdatesResponse = try await APIClient.shared.request(
            "/api/breakroom/updates?limit=\(limit)"
        )
        return response.updates
    }

    static func getNews() async throws -> [NewsItem] {
        let response: NewsResponse = try await APIClient.shared.request(
            "/api/breakroom/news"
        )
        return response.items
    }
}
