import Foundation

enum GamesAPIService {
    private static let gameKey = "haulonaut"

    /// GET /api/games/haulonaut — returns game info, active instances, and user's characters.
    static func getGameInfo() async throws -> HaulonautGameInfoResponse {
        try await APIClient.shared.request("/api/games/\(gameKey)")
    }

    /// POST /api/games/haulonaut/characters — create a new character in an instance.
    static func createCharacter(displayName: String, instanceId: Int) async throws -> HaulonautCharacter {
        let body = HaulonautCreateCharacterRequest(displayName: displayName, instanceId: instanceId)
        let response: HaulonautCreateCharacterResponse = try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters",
            method: "POST",
            body: body
        )
        return response.character
    }

    /// GET /api/games/haulonaut/characters/:id — returns character snapshot with sector info.
    static func getCharacter(id: Int) async throws -> HaulonautCharacterSnapshotResponse {
        try await APIClient.shared.request("/api/games/\(gameKey)/characters/\(id)")
    }

    /// POST /api/games/haulonaut/characters/:id/navigate — move to a connected sector.
    static func navigate(characterId: Int, toSectorId: Int) async throws -> HaulonautNavigateResponse {
        let body = HaulonautNavigateRequest(toSectorId: toSectorId)
        return try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/navigate",
            method: "POST",
            body: body
        )
    }

    /// GET /api/games/haulonaut/items — returns catalog of items available for purchase.
    static func getItems() async throws -> [HaulonautItem] {
        let response: HaulonautItemsResponse = try await APIClient.shared.request("/api/games/\(gameKey)/items")
        return response.items
    }

    /// POST /api/games/haulonaut/characters/:id/purchase — buy an item from an outpost.
    static func purchase(characterId: Int, itemKey: String, quantity: Int = 1) async throws -> HaulonautPurchaseResponse {
        let body = HaulonautPurchaseRequest(itemKey: itemKey, quantity: quantity)
        return try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/purchase",
            method: "POST",
            body: body
        )
    }

    // MARK: - Star Charts

    /// GET /api/games/haulonaut/characters/:id/known-locations — returns discovered locations with distances.
    static func getKnownLocations(characterId: Int) async throws -> [HaulonautKnownLocation] {
        let response: HaulonautKnownLocationsResponse = try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/known-locations"
        )
        return response.locations
    }

    /// GET /api/games/haulonaut/characters/:id/route/:sectorId — returns shortest path to sector.
    static func getRoute(characterId: Int, toSectorId: Int) async throws -> [HaulonautRouteWaypoint] {
        let response: HaulonautRouteResponse = try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/route/\(toSectorId)"
        )
        return response.path
    }
}
