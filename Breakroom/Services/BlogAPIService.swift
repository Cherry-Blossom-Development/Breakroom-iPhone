import Foundation

enum BlogAPIService {
    static func getFeed() async throws -> [BlogPost] {
        let response: BlogFeedResponse = try await APIClient.shared.request(
            "/api/blog/feed"
        )
        return response.posts
    }

    static func viewPost(id: Int) async throws -> BlogPost {
        let response: BlogViewResponse = try await APIClient.shared.request(
            "/api/blog/view/\(id)"
        )
        return response.post
    }
}
