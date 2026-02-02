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

    // MARK: - Blog Management

    static func getMyPosts() async throws -> [BlogPost] {
        let response: BlogPostsResponse = try await APIClient.shared.request(
            "/api/blog/posts"
        )
        return response.posts
    }

    static func getPost(id: Int) async throws -> BlogPost {
        let response: BlogPostResponse = try await APIClient.shared.request(
            "/api/blog/posts/\(id)"
        )
        return response.post
    }

    static func createPost(title: String, content: String, isPublished: Bool) async throws -> BlogPost {
        let body = CreateBlogPostRequest(title: title, content: content, isPublished: isPublished)
        let response: BlogPostResponse = try await APIClient.shared.request(
            "/api/blog/posts",
            method: "POST",
            body: body
        )
        return response.post
    }

    static func updatePost(id: Int, title: String, content: String, isPublished: Bool) async throws -> BlogPost {
        let body = UpdateBlogPostRequest(title: title, content: content, isPublished: isPublished)
        let response: BlogPostResponse = try await APIClient.shared.request(
            "/api/blog/posts/\(id)",
            method: "PUT",
            body: body
        )
        return response.post
    }

    static func deletePost(id: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/blog/posts/\(id)",
            method: "DELETE"
        )
    }

    static func uploadImage(imageData: Data, filename: String) async throws -> String {
        let response: BlogImageUploadResponse = try await APIClient.shared.uploadMultipart(
            "/api/blog/upload-image",
            fileData: imageData,
            fieldName: "image",
            filename: filename,
            mimeType: "image/jpeg"
        )
        return response.url
    }

    // MARK: - Blog Settings

    static func getSettings() async throws -> BlogSettings? {
        let response: BlogSettingsResponse = try await APIClient.shared.request(
            "/api/blog/settings"
        )
        return response.settings
    }

    static func createSettings(blogUrl: String, blogName: String) async throws -> BlogSettings {
        let body = SaveBlogSettingsRequest(blogUrl: blogUrl, blogName: blogName)
        let response: BlogSettingsResponse = try await APIClient.shared.request(
            "/api/blog/settings",
            method: "POST",
            body: body
        )
        return response.settings!
    }

    static func updateSettings(blogUrl: String, blogName: String) async throws -> BlogSettings {
        let body = SaveBlogSettingsRequest(blogUrl: blogUrl, blogName: blogName)
        let response: BlogSettingsResponse = try await APIClient.shared.request(
            "/api/blog/settings",
            method: "PUT",
            body: body
        )
        return response.settings!
    }

    static func checkURL(blogUrl: String) async throws -> Bool {
        let response: BlogURLCheckResponse = try await APIClient.shared.request(
            "/api/blog/check-url/\(blogUrl)"
        )
        return response.available
    }
}
