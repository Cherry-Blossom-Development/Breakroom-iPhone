import Foundation

// MARK: - Collection

struct Collection: Codable, Identifiable, Hashable {
    let id: Int
    let userId: Int?
    let name: String
    let settings: CollectionSettings?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case settings
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CollectionSettings: Codable, Hashable {
    let backgroundColor: String?

    enum CodingKeys: String, CodingKey {
        case backgroundColor = "background_color"
    }
}

// MARK: - Collection Item

struct CollectionItem: Codable, Identifiable {
    let id: Int
    let collectionId: Int?
    let userId: Int?
    let name: String
    let description: String?
    let imagePath: String?
    let displayOrder: Int?
    let priceCents: Int?
    let isAvailable: Bool
    let shippingCostCents: Int?
    let weightOz: Double?
    let lengthIn: Double?
    let widthIn: Double?
    let heightIn: Double?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case collectionId = "collection_id"
        case userId = "user_id"
        case name
        case description
        case imagePath = "image_path"
        case displayOrder = "display_order"
        case priceCents = "price_cents"
        case isAvailable = "is_available"
        case shippingCostCents = "shipping_cost_cents"
        case weightOz = "weight_oz"
        case lengthIn = "length_in"
        case widthIn = "width_in"
        case heightIn = "height_in"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        collectionId = try container.decodeIfPresent(Int.self, forKey: .collectionId)
        userId = try container.decodeIfPresent(Int.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        displayOrder = try container.decodeIfPresent(Int.self, forKey: .displayOrder)
        priceCents = try container.decodeIfPresent(Int.self, forKey: .priceCents)
        shippingCostCents = try container.decodeIfPresent(Int.self, forKey: .shippingCostCents)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)

        // Handle is_available as Int (0/1) or Bool
        if let intValue = try? container.decode(Int.self, forKey: .isAvailable) {
            isAvailable = intValue != 0
        } else if let boolValue = try? container.decode(Bool.self, forKey: .isAvailable) {
            isAvailable = boolValue
        } else {
            isAvailable = false
        }

        // Handle numeric fields that may come as strings from the API
        weightOz = Self.decodeDoubleOrString(from: container, forKey: .weightOz)
        lengthIn = Self.decodeDoubleOrString(from: container, forKey: .lengthIn)
        widthIn = Self.decodeDoubleOrString(from: container, forKey: .widthIn)
        heightIn = Self.decodeDoubleOrString(from: container, forKey: .heightIn)
    }

    private static func decodeDoubleOrString(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Double? {
        if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
            return doubleValue
        }
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            return Double(stringValue)
        }
        return nil
    }

    // MARK: - Computed Properties

    var priceFormatted: String? {
        guard let cents = priceCents else { return nil }
        let dollars = Double(cents) / 100.0
        return String(format: "$%.2f", dollars)
    }

    var shippingCostFormatted: String? {
        guard let cents = shippingCostCents else { return nil }
        if cents == 0 { return "Free shipping" }
        let dollars = Double(cents) / 100.0
        return String(format: "+ $%.2f shipping", dollars)
    }

    var isListed: Bool {
        isAvailable
    }
}

struct CollectionItemSettings: Codable {
    // Reserved for future use
}

// MARK: - API Responses

struct CollectionsResponse: Decodable {
    let collections: [Collection]
}

struct CollectionItemsResponse: Decodable {
    let items: [CollectionItem]
}

// MARK: - API Requests

struct CreateCollectionRequest: Encodable {
    let name: String
    let settings: CollectionSettings?
}

struct UpdateCollectionRequest: Encodable {
    let name: String
    let settings: CollectionSettings?
}
