import Foundation

enum CollectionsAPIService {

    // MARK: - Collections

    /// Get all collections for the authenticated user
    static func getCollections() async throws -> [Collection] {
        try await APIClient.shared.request("/api/collections")
    }

    /// Get a specific collection
    static func getCollection(id: Int) async throws -> Collection {
        try await APIClient.shared.request("/api/collections/\(id)")
    }

    /// Create a new collection
    static func createCollection(name: String, backgroundColor: String? = nil) async throws -> Collection {
        let settings = backgroundColor != nil ? CollectionSettings(backgroundColor: backgroundColor) : nil
        let body = CreateCollectionRequest(name: name, settings: settings)
        return try await APIClient.shared.request("/api/collections", method: "POST", body: body)
    }

    /// Update a collection
    static func updateCollection(id: Int, name: String, backgroundColor: String? = nil) async throws -> Collection {
        let settings = CollectionSettings(backgroundColor: backgroundColor)
        let body = UpdateCollectionRequest(name: name, settings: settings)
        return try await APIClient.shared.request("/api/collections/\(id)", method: "PUT", body: body)
    }

    /// Delete a collection
    static func deleteCollection(id: Int) async throws {
        try await APIClient.shared.requestVoid("/api/collections/\(id)", method: "DELETE")
    }

    // MARK: - Collection Items

    /// Get all items in a collection
    static func getItems(collectionId: Int) async throws -> [CollectionItem] {
        try await APIClient.shared.request("/api/collections/\(collectionId)/items")
    }

    /// Debug: Get raw JSON response for items
    static func getItemsRaw(collectionId: Int) async throws -> String {
        let url = URL(string: "\(APIClient.shared.baseURL)/api/collections/\(collectionId)/items")!
        var request = URLRequest(url: url)
        if let token = KeychainManager.bearerToken {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await URLSession.shared.data(for: request)
        return String(data: data, encoding: .utf8) ?? "Could not decode response"
    }

    /// Create a new item in a collection
    static func createItem(
        collectionId: Int,
        name: String,
        description: String?,
        imageData: Data?,
        priceCents: Int?,
        isAvailable: Bool,
        shippingCostCents: Int?,
        weightOz: Double?,
        lengthIn: Double?,
        widthIn: Double?,
        heightIn: Double?
    ) async throws -> CollectionItem {
        let url = URL(string: "\(APIClient.shared.baseURL)/api/collections/\(collectionId)/items")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        if let token = KeychainManager.bearerToken {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Name (required)
        body.appendFormField(name: "name", value: name, boundary: boundary)

        // Description
        if let description, !description.isEmpty {
            body.appendFormField(name: "description", value: description, boundary: boundary)
        }

        // Price (convert cents to dollars for API)
        if let priceCents {
            let priceString = String(format: "%.2f", Double(priceCents) / 100.0)
            body.appendFormField(name: "price", value: priceString, boundary: boundary)
        }

        // Availability
        body.appendFormField(name: "is_available", value: isAvailable ? "true" : "false", boundary: boundary)

        // Shipping cost
        if let shippingCostCents {
            let shippingString = String(format: "%.2f", Double(shippingCostCents) / 100.0)
            body.appendFormField(name: "shipping_cost", value: shippingString, boundary: boundary)
        }

        // Weight
        if let weightOz {
            body.appendFormField(name: "weight_oz", value: String(weightOz), boundary: boundary)
        }

        // Dimensions
        if let lengthIn {
            body.appendFormField(name: "length_in", value: String(lengthIn), boundary: boundary)
        }
        if let widthIn {
            body.appendFormField(name: "width_in", value: String(widthIn), boundary: boundary)
        }
        if let heightIn {
            body.appendFormField(name: "height_in", value: String(heightIn), boundary: boundary)
        }

        // Image
        if let imageData {
            body.appendFormFile(name: "image", filename: "image.jpg", mimeType: "image/jpeg", data: imageData, boundary: boundary)
        }

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError("Failed to create item: \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(CollectionItem.self, from: data)
    }

    /// Update an item in a collection
    static func updateItem(
        collectionId: Int,
        itemId: Int,
        name: String,
        description: String?,
        imageData: Data?,
        priceCents: Int?,
        isAvailable: Bool,
        shippingCostCents: Int?,
        weightOz: Double?,
        lengthIn: Double?,
        widthIn: Double?,
        heightIn: Double?
    ) async throws -> CollectionItem {
        let url = URL(string: "\(APIClient.shared.baseURL)/api/collections/\(collectionId)/items/\(itemId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        if let token = KeychainManager.bearerToken {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Name (required)
        body.appendFormField(name: "name", value: name, boundary: boundary)

        // Description
        if let description, !description.isEmpty {
            body.appendFormField(name: "description", value: description, boundary: boundary)
        }

        // Price
        if let priceCents {
            let priceString = String(format: "%.2f", Double(priceCents) / 100.0)
            body.appendFormField(name: "price", value: priceString, boundary: boundary)
        }

        // Availability
        body.appendFormField(name: "is_available", value: isAvailable ? "true" : "false", boundary: boundary)

        // Shipping cost
        if let shippingCostCents {
            let shippingString = String(format: "%.2f", Double(shippingCostCents) / 100.0)
            body.appendFormField(name: "shipping_cost", value: shippingString, boundary: boundary)
        }

        // Weight
        if let weightOz {
            body.appendFormField(name: "weight_oz", value: String(weightOz), boundary: boundary)
        }

        // Dimensions
        if let lengthIn {
            body.appendFormField(name: "length_in", value: String(lengthIn), boundary: boundary)
        }
        if let widthIn {
            body.appendFormField(name: "width_in", value: String(widthIn), boundary: boundary)
        }
        if let heightIn {
            body.appendFormField(name: "height_in", value: String(heightIn), boundary: boundary)
        }

        // Image (only if new image provided)
        if let imageData {
            body.appendFormFile(name: "image", filename: "image.jpg", mimeType: "image/jpeg", data: imageData, boundary: boundary)
        }

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError("Failed to update item: \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(CollectionItem.self, from: data)
    }

    /// Delete an item from a collection
    static func deleteItem(collectionId: Int, itemId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/collections/\(collectionId)/items/\(itemId)",
            method: "DELETE"
        )
    }

    // MARK: - Shipping Settings

    /// Get shipping settings
    static func getShippingSettings() async throws -> ShippingSettings? {
        try await APIClient.shared.request("/api/shipping/settings")
    }

    /// Save shipping settings
    static func saveShippingSettings(_ settings: ShippingSettings) async throws -> ShippingSettings {
        try await APIClient.shared.request("/api/shipping/settings", method: "POST", body: settings)
    }

    // MARK: - Orders

    /// Get all orders for the seller
    static func getOrders() async throws -> [Order] {
        try await APIClient.shared.request("/api/storefront/orders")
    }

    /// Mark an order as shipped
    static func markOrderShipped(orderId: Int, trackingNumber: String?, trackingCarrier: String?) async throws -> Order {
        struct ShipRequest: Encodable {
            let tracking_number: String?
            let tracking_carrier: String?
        }
        let body = ShipRequest(tracking_number: trackingNumber, tracking_carrier: trackingCarrier)
        return try await APIClient.shared.request("/api/storefront/orders/\(orderId)/ship", method: "PUT", body: body)
    }

    // MARK: - Billing / Stripe Connect

    /// Get the user's billing plan (free vs pro)
    static func getBillingPlan() async throws -> BillingPlan {
        try await APIClient.shared.request("/api/billing/plan")
    }

    /// Get Stripe Connect status
    static func getConnectStatus() async throws -> ConnectStatus {
        try await APIClient.shared.request("/api/billing/connect/status")
    }

    /// Start Stripe Connect onboarding - returns URL to open
    static func startConnect() async throws -> ConnectStartResponse {
        try await APIClient.shared.request("/api/billing/connect/start", method: "POST")
    }

    // MARK: - Storefront

    /// Get the user's storefront settings
    static func getStorefront() async throws -> Storefront? {
        try await APIClient.shared.request("/api/storefront")
    }

    /// Save storefront settings
    static func saveStorefront(
        storeUrl: String?,
        pageTitle: String?,
        content: String?,
        settings: StorefrontSettings?
    ) async throws {
        struct SaveRequest: Encodable {
            let store_url: String?
            let page_title: String?
            let content: String?
            let settings: StorefrontSettings?
        }
        let body = SaveRequest(
            store_url: storeUrl,
            page_title: pageTitle,
            content: content,
            settings: settings
        )
        try await APIClient.shared.requestVoid("/api/storefront", method: "PUT", body: body)
    }

    /// Check if a store URL is available
    static func checkStoreUrl(_ url: String) async throws -> StorefrontUrlCheck {
        try await APIClient.shared.request("/api/storefront/check-url/\(url)")
    }
}

// MARK: - Data Extensions for Multipart Form

private extension Data {
    mutating func appendFormField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendFormFile(name: String, filename: String, mimeType: String, data: Data, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
