import Foundation

enum DiscoverAPIService {
    /// Fetch public galleries that artists have opted to make discoverable
    static func getPublicGalleries() async throws -> [DiscoverGallery] {
        let response: DiscoverGalleriesResponse = try await APIClient.shared.request(
            "/api/gallery/public"
        )
        return response.galleries
    }

    /// Fetch public storefronts (showcases) that artists have opted to make discoverable
    static func getPublicStorefronts() async throws -> [DiscoverStorefront] {
        let response: DiscoverStorefrontsResponse = try await APIClient.shared.request(
            "/api/storefront/public"
        )
        return response.storefronts
    }

    /// Fetch public blogs that authors have opted to make discoverable
    static func getPublicBlogs() async throws -> [DiscoverBlog] {
        let response: DiscoverBlogsResponse = try await APIClient.shared.request(
            "/api/blog/public"
        )
        return response.blogs
    }
}
