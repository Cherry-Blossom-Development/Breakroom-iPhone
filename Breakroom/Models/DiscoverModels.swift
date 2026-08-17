import Foundation

// MARK: - Artist Info (shared between galleries and storefronts)

struct DiscoverArtist: Codable, Hashable {
    let handle: String
    let firstName: String?
    let lastName: String?
    let photoPath: String?

    enum CodingKeys: String, CodingKey {
        case handle
        case firstName = "first_name"
        case lastName = "last_name"
        case photoPath = "photo_path"
    }

    var displayName: String {
        if let first = firstName, !first.isEmpty {
            if let last = lastName, !last.isEmpty {
                return "\(first) \(last)"
            }
            return first
        }
        return "@\(handle)"
    }

    var initial: String {
        firstName?.first.map(String.init) ?? handle.first.map(String.init) ?? "?"
    }
}

// MARK: - Public Gallery

struct DiscoverGallery: Codable, Identifiable, Hashable {
    let galleryUrl: String
    let galleryName: String
    let bio: String?
    let artworkCount: Int
    let coverImagePath: String?
    let artist: DiscoverArtist

    var id: String { galleryUrl }

    enum CodingKeys: String, CodingKey {
        case galleryUrl = "gallery_url"
        case galleryName = "gallery_name"
        case bio
        case artworkCount = "artwork_count"
        case coverImagePath = "cover_image_path"
        case artist
    }
}

struct DiscoverGalleriesResponse: Decodable {
    let galleries: [DiscoverGallery]
}

// MARK: - Public Storefront (Showcase)

struct DiscoverStorefront: Codable, Identifiable, Hashable {
    let storeUrl: String
    let pageTitle: String?
    let itemCount: Int
    let coverImagePath: String?
    let artist: DiscoverArtist

    var id: String { storeUrl }

    var displayTitle: String {
        pageTitle ?? storeUrl
    }

    enum CodingKeys: String, CodingKey {
        case storeUrl = "store_url"
        case pageTitle = "page_title"
        case itemCount = "item_count"
        case coverImagePath = "cover_image_path"
        case artist
    }
}

struct DiscoverStorefrontsResponse: Decodable {
    let storefronts: [DiscoverStorefront]
}
