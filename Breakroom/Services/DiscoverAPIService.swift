import Foundation

/// Default page size for Discover sections, matching web/Android clients
private let discoverPageSize = 8

enum DiscoverAPIService {
    /// Fetch public galleries with pagination and optional search
    static func getPublicGalleries(
        limit: Int = discoverPageSize,
        offset: Int = 0,
        query: String? = nil
    ) async throws -> DiscoverGalleriesResponse {
        var path = "/api/gallery/public?limit=\(limit)&offset=\(offset)"
        if let q = query?.trimmingCharacters(in: .whitespaces), !q.isEmpty {
            path += "&q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)"
        }
        return try await APIClient.shared.request(path)
    }

    /// Fetch public storefronts (showcases) with pagination and optional search
    static func getPublicStorefronts(
        limit: Int = discoverPageSize,
        offset: Int = 0,
        query: String? = nil
    ) async throws -> DiscoverStorefrontsResponse {
        var path = "/api/storefront/public?limit=\(limit)&offset=\(offset)"
        if let q = query?.trimmingCharacters(in: .whitespaces), !q.isEmpty {
            path += "&q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)"
        }
        return try await APIClient.shared.request(path)
    }

    /// Fetch public blogs with pagination and optional search
    static func getPublicBlogs(
        limit: Int = discoverPageSize,
        offset: Int = 0,
        query: String? = nil
    ) async throws -> DiscoverBlogsResponse {
        var path = "/api/blog/public?limit=\(limit)&offset=\(offset)"
        if let q = query?.trimmingCharacters(in: .whitespaces), !q.isEmpty {
            path += "&q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)"
        }
        return try await APIClient.shared.request(path)
    }
}
