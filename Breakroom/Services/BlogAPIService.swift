import Foundation

enum BlogAPIService {
    static func getFeed() async throws -> [BlogPost] {
        let response: BlogFeedResponse = try await APIClient.shared.request(
            "/api/blog/feed"
        )
        return response.posts
    }
}
