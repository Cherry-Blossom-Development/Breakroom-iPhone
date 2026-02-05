import Foundation

// MARK: - Gallery Settings

struct GallerySettings: Codable, Identifiable {
    let id: Int
    let userId: Int?
    let galleryUrl: String
    let galleryName: String
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case galleryUrl = "gallery_url"
        case galleryName = "gallery_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var publicUrl: String {
        "\(APIClient.shared.baseURL)/g/\(galleryUrl)"
    }
}

// MARK: - Artwork

struct Artwork: Codable, Identifiable, Hashable {
    let id: Int
    let userId: Int?
    let title: String
    let description: String?
    let imagePath: String
    let isPublished: Int?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case userId = "user_id"
        case imagePath = "image_path"
        case isPublished = "is_published"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isPublishedBool: Bool {
        (isPublished ?? 0) != 0
    }

    var imageURL: URL? {
        URL(string: "\(APIClient.shared.baseURL)/api/uploads/\(imagePath)")
    }
}

// MARK: - Public Gallery

struct PublicGallery: Codable {
    let id: Int
    let galleryUrl: String
    let galleryName: String
    let artist: GalleryArtist

    enum CodingKeys: String, CodingKey {
        case id
        case galleryUrl = "gallery_url"
        case galleryName = "gallery_name"
        case artist
    }
}

struct GalleryArtist: Codable {
    let handle: String?
    let firstName: String?
    let lastName: String?
    let photoPath: String?
    let bio: String?

    enum CodingKeys: String, CodingKey {
        case handle, bio
        case firstName = "first_name"
        case lastName = "last_name"
        case photoPath = "photo_path"
    }

    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? (handle ?? "Unknown Artist") : parts.joined(separator: " ")
    }

    var photoURL: URL? {
        guard let photoPath, !photoPath.isEmpty else { return nil }
        return URL(string: "\(APIClient.shared.baseURL)/api/uploads/\(photoPath)")
    }
}

// MARK: - API Response Types

struct GallerySettingsResponse: Decodable {
    let settings: GallerySettings?
}

struct ArtworksResponse: Decodable {
    let artworks: [Artwork]
}

struct ArtworkResponse: Decodable {
    let artwork: Artwork
}

struct PublicGalleryResponse: Decodable {
    let gallery: PublicGallery
    let artworks: [Artwork]
}

struct GalleryUrlCheckResponse: Decodable {
    let available: Bool
    let isOwn: Bool?
}

// MARK: - API Request Types

struct CreateGallerySettingsRequest: Encodable {
    let galleryUrl: String?
    let galleryName: String?

    enum CodingKeys: String, CodingKey {
        case galleryUrl = "gallery_url"
        case galleryName = "gallery_name"
    }
}

struct UpdateGallerySettingsRequest: Encodable {
    let galleryUrl: String?
    let galleryName: String?

    enum CodingKeys: String, CodingKey {
        case galleryUrl = "gallery_url"
        case galleryName = "gallery_name"
    }
}

struct UpdateArtworkRequest: Encodable {
    let title: String?
    let description: String?
    let isPublished: Bool?

    enum CodingKeys: String, CodingKey {
        case title, description
        case isPublished = "is_published"
    }
}
