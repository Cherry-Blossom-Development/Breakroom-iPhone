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

    // MARK: - Drift

    /// POST /api/games/haulonaut/characters/:id/drift — uncontrolled movement toward nearest planet when fuel is 0.
    static func drift(characterId: Int) async throws -> HaulonautDriftResponse {
        try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/drift",
            method: "POST"
        )
    }

    // MARK: - Cycles

    /// GET /api/games/haulonaut/characters/:id/cycles — lightweight re-sync for cycle balance.
    static func getCycles(characterId: Int) async throws -> HaulonautCyclesResponse {
        try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/cycles"
        )
    }

    // MARK: - Planet Docking

    /// POST /api/games/haulonaut/characters/:id/dock — land on a planet.
    static func dock(characterId: Int) async throws -> HaulonautDockResponse {
        try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/dock",
            method: "POST"
        )
    }

    /// POST /api/games/haulonaut/characters/:id/launch — return to space from a docked state.
    static func launch(characterId: Int) async throws -> HaulonautActionAck {
        try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/launch",
            method: "POST"
        )
    }

    // MARK: - Surface Exploration

    /// POST /api/games/haulonaut/characters/:id/exit-craft — step onto the planet surface.
    static func exitCraft(characterId: Int) async throws -> HaulonautExitCraftResponse {
        try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/exit-craft",
            method: "POST"
        )
    }

    /// POST /api/games/haulonaut/characters/:id/return-to-ship — return to the ship from surface.
    static func returnToShip(characterId: Int) async throws -> HaulonautActionAck {
        try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/return-to-ship",
            method: "POST"
        )
    }

    /// POST /api/games/haulonaut/characters/:id/drive-buggy — move the buggy one cell on the surface.
    static func driveBuggy(characterId: Int, direction: String) async throws -> HaulonautDriveBuggyResponse {
        let body = HaulonautDriveBuggyRequest(direction: direction)
        return try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/drive-buggy",
            method: "POST",
            body: body
        )
    }

    // MARK: - Gifting & Trading

    /// POST /api/games/haulonaut/characters/:id/give — give credits to another player in the sector.
    static func giveCredits(characterId: Int, toCharacterId: Int, credits: Int) async throws -> HaulonautGiveResponse {
        let body = HaulonautGiveRequest(toCharacterId: toCharacterId, credits: credits)
        return try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/give",
            method: "POST",
            body: body
        )
    }

    /// GET /api/games/haulonaut/characters/:id/trade-offers — get pending trade offers.
    static func getTradeOffers(characterId: Int) async throws -> [HaulonautTradeOfferSummary] {
        let response: HaulonautTradeOffersResponse = try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/trade-offers"
        )
        return response.offers
    }

    /// POST /api/games/haulonaut/characters/:id/trade-offers — create a trade offer.
    static func createTradeOffer(characterId: Int, toCharacterId: Int, itemKey: String, quantity: Int, credits: Int) async throws -> HaulonautCreateTradeOfferResponse {
        let body = HaulonautTradeOfferRequest(toCharacterId: toCharacterId, itemKey: itemKey, quantity: quantity, credits: credits)
        return try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/trade-offers",
            method: "POST",
            body: body
        )
    }

    /// POST /api/games/haulonaut/characters/:id/trade-offers/:offerId/accept — accept a trade offer.
    static func acceptTradeOffer(characterId: Int, offerId: Int) async throws -> HaulonautTradeAcceptResponse {
        try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/trade-offers/\(offerId)/accept",
            method: "POST"
        )
    }

    /// POST /api/games/haulonaut/characters/:id/trade-offers/:offerId/decline — decline a trade offer.
    static func declineTradeOffer(characterId: Int, offerId: Int) async throws -> HaulonautActionAck {
        try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/trade-offers/\(offerId)/decline",
            method: "POST"
        )
    }

    // MARK: - Combat

    /// POST /api/games/haulonaut/characters/:id/attack — attack another player in the sector.
    static func attack(characterId: Int, toCharacterId: Int) async throws -> HaulonautAttackResponse {
        let body = HaulonautAttackRequest(toCharacterId: toCharacterId)
        return try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/attack",
            method: "POST",
            body: body
        )
    }

    // MARK: - Target Info

    /// GET /api/games/haulonaut/characters/:id/target-info/:targetId — get target's cargo and info.
    static func getTargetInfo(characterId: Int, targetId: Int) async throws -> HaulonautTargetInfoResponse {
        try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/target-info/\(targetId)"
        )
    }

    // MARK: - Probes

    /// GET /api/games/haulonaut/characters/:id/probes — get active mission + pending report.
    static func getProbes(characterId: Int) async throws -> HaulonautProbesResponse {
        try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/probes"
        )
    }

    /// POST /api/games/haulonaut/characters/:id/probes/deploy — deploy a probe with mission type.
    static func deployProbe(characterId: Int, missionType: String, searchItemKey: String? = nil) async throws -> HaulonautDeployProbeResponse {
        let body = HaulonautDeployProbeRequest(missionType: missionType, searchItemKey: searchItemKey)
        return try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/probes/deploy",
            method: "POST",
            body: body
        )
    }

    /// POST /api/games/haulonaut/characters/:id/probes/:missionId/acknowledge — dismiss a probe report.
    static func acknowledgeProbeReport(characterId: Int, missionId: Int) async throws -> HaulonautActionAck {
        try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/probes/\(missionId)/acknowledge",
            method: "POST"
        )
    }

    // MARK: - Tracking Buoys

    /// GET /api/games/haulonaut/characters/:id/buoys — get all deployed buoys.
    static func getBuoys(characterId: Int) async throws -> [HaulonautBuoy] {
        let response: HaulonautBuoysResponse = try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/buoys"
        )
        return response.buoys
    }

    /// POST /api/games/haulonaut/characters/:id/buoys/drop — drop a tracking buoy in current sector.
    static func dropBuoy(characterId: Int) async throws -> HaulonautDropBuoyResponse {
        try await APIClient.shared.request(
            "/api/games/\(gameKey)/characters/\(characterId)/buoys/drop",
            method: "POST"
        )
    }
}
