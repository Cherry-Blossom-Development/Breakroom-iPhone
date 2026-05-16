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

// MARK: - Shipping Settings

struct ShippingSettings: Codable {
    var addressLine1: String?
    var addressLine2: String?
    var city: String?
    var stateRegion: String?
    var zip: String?
    var country: String
    var shipDestinations: String
    var processingTime: String

    enum CodingKeys: String, CodingKey {
        case addressLine1 = "address_line1"
        case addressLine2 = "address_line2"
        case city
        case stateRegion = "state_region"
        case zip
        case country
        case shipDestinations = "ship_destinations"
        case processingTime = "processing_time"
    }

    init(
        addressLine1: String? = nil,
        addressLine2: String? = nil,
        city: String? = nil,
        stateRegion: String? = nil,
        zip: String? = nil,
        country: String = "US",
        shipDestinations: String = "us_only",
        processingTime: String = "1_2_days"
    ) {
        self.addressLine1 = addressLine1
        self.addressLine2 = addressLine2
        self.city = city
        self.stateRegion = stateRegion
        self.zip = zip
        self.country = country
        self.shipDestinations = shipDestinations
        self.processingTime = processingTime
    }

    var processingTimeDisplay: String {
        switch processingTime {
        case "same_day": return "Same day"
        case "1_2_days": return "1–2 business days"
        case "3_5_days": return "3–5 business days"
        case "1_2_weeks": return "1–2 weeks"
        case "2_4_weeks": return "2–4 weeks"
        default: return processingTime
        }
    }

    var shipDestinationsDisplay: String {
        switch shipDestinations {
        case "us_only": return "United States only"
        case "us_canada": return "United States & Canada"
        case "worldwide": return "Worldwide"
        default: return shipDestinations
        }
    }
}

// MARK: - Order

struct Order: Codable, Identifiable {
    let id: Int
    let buyerId: Int?
    let sellerId: Int?
    let itemId: Int?
    let itemName: String?
    let itemImage: String?
    let itemPriceCents: Int?
    let shippingCostCents: Int?
    let totalCents: Int?
    let status: String
    let buyerName: String?
    let buyerEmail: String?
    let shipToName: String?
    let shipToAddress1: String?
    let shipToAddress2: String?
    let shipToCity: String?
    let shipToState: String?
    let shipToZip: String?
    let shipToCountry: String?
    let trackingNumber: String?
    let trackingCarrier: String?
    let shippedAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case buyerId = "buyer_id"
        case sellerId = "seller_id"
        case itemId = "item_id"
        case itemName = "item_name"
        case itemImage = "item_image"
        case itemPriceCents = "item_price_cents"
        case shippingCostCents = "shipping_cost_cents"
        case totalCents = "total_cents"
        case status
        case buyerName = "buyer_name"
        case buyerEmail = "buyer_email"
        case shipToName = "ship_to_name"
        case shipToAddress1 = "ship_to_address1"
        case shipToAddress2 = "ship_to_address2"
        case shipToCity = "ship_to_city"
        case shipToState = "ship_to_state"
        case shipToZip = "ship_to_zip"
        case shipToCountry = "ship_to_country"
        case trackingNumber = "tracking_number"
        case trackingCarrier = "tracking_carrier"
        case shippedAt = "shipped_at"
        case createdAt = "created_at"
    }

    var totalFormatted: String {
        guard let cents = totalCents else { return "$0.00" }
        return String(format: "$%.2f", Double(cents) / 100.0)
    }

    var itemPriceFormatted: String {
        guard let cents = itemPriceCents else { return "$0.00" }
        return String(format: "$%.2f", Double(cents) / 100.0)
    }

    var shippingCostFormatted: String {
        guard let cents = shippingCostCents else { return "$0.00" }
        return String(format: "$%.2f", Double(cents) / 100.0)
    }

    var statusLabel: String {
        switch status {
        case "pending_payment": return "Pending payment"
        case "paid": return "Paid"
        case "processing": return "Processing"
        case "shipped": return "Shipped"
        case "delivered": return "Delivered"
        case "cancelled": return "Cancelled"
        case "refunded": return "Refunded"
        default: return status
        }
    }

    var statusColor: String {
        switch status {
        case "pending_payment": return "orange"
        case "paid": return "green"
        case "processing": return "blue"
        case "shipped": return "purple"
        case "delivered": return "green"
        case "cancelled", "refunded": return "red"
        default: return "gray"
        }
    }

    var formattedDate: String {
        guard let dateStr = createdAt else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateStr) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateStr) else { return "" }
            return formatDate(date)
        }
        return formatDate(date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    var canShip: Bool {
        status == "paid" || status == "processing"
    }
}
