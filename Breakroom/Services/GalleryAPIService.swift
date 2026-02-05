import Foundation

enum GalleryAPIService {
    // MARK: - Gallery Settings

    /// Get current user's gallery settings
    static func getSettings() async throws -> GallerySettings? {
        let response: GallerySettingsResponse = try await APIClient.shared.request("/api/gallery/settings")
        return response.settings
    }

    /// Create gallery settings
    static func createSettings(galleryUrl: String?, galleryName: String?) async throws -> GallerySettings {
        let body = CreateGallerySettingsRequest(galleryUrl: galleryUrl, galleryName: galleryName)
        let response: GallerySettingsResponse = try await APIClient.shared.request(
            "/api/gallery/settings",
            method: "POST",
            body: body
        )
        guard let settings = response.settings else {
            throw APIError.serverError("Failed to create gallery settings")
        }
        return settings
    }

    /// Update gallery settings
    static func updateSettings(galleryUrl: String?, galleryName: String?) async throws -> GallerySettings {
        let body = UpdateGallerySettingsRequest(galleryUrl: galleryUrl, galleryName: galleryName)
        let response: GallerySettingsResponse = try await APIClient.shared.request(
            "/api/gallery/settings",
            method: "PUT",
            body: body
        )
        guard let settings = response.settings else {
            throw APIError.serverError("Failed to update gallery settings")
        }
        return settings
    }

    /// Check if a gallery URL is available
    static func checkUrl(_ galleryUrl: String) async throws -> GalleryUrlCheckResponse {
        let encoded = galleryUrl.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? galleryUrl
        return try await APIClient.shared.request("/api/gallery/check-url/\(encoded)")
    }

    // MARK: - Artworks

    /// Get all artworks for current user
    static func getArtworks() async throws -> [Artwork] {
        let response: ArtworksResponse = try await APIClient.shared.request("/api/gallery/artworks")
        return response.artworks
    }

    /// Get a single artwork
    static func getArtwork(id: Int) async throws -> Artwork {
        let response: ArtworkResponse = try await APIClient.shared.request("/api/gallery/artworks/\(id)")
        return response.artwork
    }

    /// Upload a new artwork
    static func uploadArtwork(
        imageData: Data,
        filename: String,
        mimeType: String,
        title: String,
        description: String?,
        isPublished: Bool
    ) async throws -> Artwork {
        // Build multipart form data manually
        let boundary = UUID().uuidString
        var body = Data()

        // Add image field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // Add title field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"title\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(title)\r\n".data(using: .utf8)!)

        // Add description field if present
        if let description, !description.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"description\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(description)\r\n".data(using: .utf8)!)
        }

        // Add isPublished field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"isPublished\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(isPublished)\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Make request
        guard let url = URL(string: "\(APIClient.shared.baseURL)/api/gallery/artworks") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let bearerToken = KeychainManager.bearerToken {
            request.setValue(bearerToken, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        let decoder = JSONDecoder()

        switch httpResponse.statusCode {
        case 200...299:
            let artworkResponse = try decoder.decode(ArtworkResponse.self, from: data)
            return artworkResponse.artwork
        case 401:
            throw APIError.unauthorized
        default:
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.displayMessage)
            }
            throw APIError.serverError("Upload failed with status \(httpResponse.statusCode)")
        }
    }

    /// Update artwork metadata
    static func updateArtwork(id: Int, title: String?, description: String?, isPublished: Bool?) async throws -> Artwork {
        let body = UpdateArtworkRequest(title: title, description: description, isPublished: isPublished)
        let response: ArtworkResponse = try await APIClient.shared.request(
            "/api/gallery/artworks/\(id)",
            method: "PUT",
            body: body
        )
        return response.artwork
    }

    /// Delete artwork
    static func deleteArtwork(id: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/gallery/artworks/\(id)",
            method: "DELETE"
        )
    }

    // MARK: - Public Gallery

    /// Get a public gallery by URL
    static func getPublicGallery(galleryUrl: String) async throws -> PublicGalleryResponse {
        let encoded = galleryUrl.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? galleryUrl
        return try await APIClient.shared.request("/api/gallery/public/\(encoded)")
    }
}
