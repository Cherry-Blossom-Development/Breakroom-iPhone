import Foundation

// MARK: - Games / Haulonaut models
// Mirrors backend/routes/games.js response shapes exactly (see that file for the
// authoritative field list — these are plain data-carrying mirrors, not independently
// designed).

struct HaulonautGame: Codable, Identifiable {
    let id: Int
    let gameKey: String
    let name: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case gameKey = "game_key"
        case name
        case description
    }
}

struct HaulonautInstance: Codable, Identifiable {
    let id: Int
    let name: String
    let startedAt: String?
    let sectorCount: Int
    let playerCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case startedAt = "started_at"
        case sectorCount = "sector_count"
        case playerCount = "player_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startedAt = try container.decodeIfPresent(String.self, forKey: .startedAt)
        sectorCount = try container.decodeIfPresent(Int.self, forKey: .sectorCount) ?? 0
        playerCount = try container.decodeIfPresent(Int.self, forKey: .playerCount) ?? 0
    }
}

// instance_id/instance_name/instance_status are only populated when this character
// came back as part of the GET /:gameKey characters list; absent from the
// create-character and single-character-fetch responses.
struct HaulonautCharacter: Codable, Identifiable {
    let id: Int
    let displayName: String
    let status: String
    let createdAt: String?
    let lastPlayedAt: String?
    let diedAt: String?
    let instanceId: Int?
    let instanceName: String?
    let instanceStatus: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case status
        case createdAt = "created_at"
        case lastPlayedAt = "last_played_at"
        case diedAt = "died_at"
        case instanceId = "instance_id"
        case instanceName = "instance_name"
        case instanceStatus = "instance_status"
    }
}

struct HaulonautSector: Codable, Identifiable {
    let id: Int
    let sectorNumber: Int
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sectorNumber = "sector_number"
        case description
    }
}

struct HaulonautConnectedSector: Codable, Identifiable {
    let id: Int
    let sectorNumber: Int
    let visited: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case sectorNumber = "sector_number"
        case visited
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        sectorNumber = try container.decode(Int.self, forKey: .sectorNumber)
        visited = try container.decodeIfPresent(Bool.self, forKey: .visited) ?? false
    }
}

struct HaulonautSectorFeature: Codable, Identifiable {
    let id: Int
    let featureType: String
    let name: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case featureType = "feature_type"
        case name
        case description
    }
}

struct HaulonautPlayerHere: Codable, Identifiable {
    let id: Int
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

// Owned quantity of an item — rations never appear here, they're a top-level pilot stat.
struct HaulonautInventoryItem: Codable, Identifiable {
    let itemKey: String
    let name: String
    let category: String
    let quantity: Int

    var id: String { itemKey }

    enum CodingKeys: String, CodingKey {
        case itemKey = "item_key"
        case name
        case category
        case quantity
    }
}

// Catalog entry (GET /items) — distinct from HaulonautInventoryItem, which is what a
// character owns.
struct HaulonautItem: Codable, Identifiable {
    let id: Int
    let itemKey: String
    let name: String
    let category: String
    let description: String?
    let basePrice: Int

    enum CodingKeys: String, CodingKey {
        case id
        case itemKey = "item_key"
        case name
        case category
        case description
        case basePrice = "base_price"
    }
}

// MARK: - Surface Exploration Models

/// A planet's low-res exploration grid. `revealed` is a flat list of row-major cell indices
/// (index = y * gridWidth + x) uncovered so far; everything else is fog. The ship sits at
/// (shipX, shipY); the buggy at (buggyX, buggyY).
struct HaulonautSurfaceMap: Codable {
    let gridWidth: Int
    let gridHeight: Int
    let shipX: Int
    let shipY: Int
    let buggyX: Int
    let buggyY: Int
    let revealed: [Int]

    init(gridWidth: Int = 12, gridHeight: Int = 8, shipX: Int = 0, shipY: Int = 0,
         buggyX: Int = 0, buggyY: Int = 0, revealed: [Int] = []) {
        self.gridWidth = gridWidth
        self.gridHeight = gridHeight
        self.shipX = shipX
        self.shipY = shipY
        self.buggyX = buggyX
        self.buggyY = buggyY
        self.revealed = revealed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gridWidth = try container.decodeIfPresent(Int.self, forKey: .gridWidth) ?? 12
        gridHeight = try container.decodeIfPresent(Int.self, forKey: .gridHeight) ?? 8
        shipX = try container.decodeIfPresent(Int.self, forKey: .shipX) ?? 0
        shipY = try container.decodeIfPresent(Int.self, forKey: .shipY) ?? 0
        buggyX = try container.decodeIfPresent(Int.self, forKey: .buggyX) ?? 0
        buggyY = try container.decodeIfPresent(Int.self, forKey: .buggyY) ?? 0
        revealed = try container.decodeIfPresent([Int].self, forKey: .revealed) ?? []
    }
}

/// Resource deltas from a landing event (first-visit discovery).
struct HaulonautLandingEffects: Codable {
    let credits: Int?
    let rations: Int?
    let fuel: Int?
}

// MARK: - API Response Envelopes

struct HaulonautGameInfoResponse: Codable {
    let game: HaulonautGame
    let instances: [HaulonautInstance]
    let characters: [HaulonautCharacter]
    let isAdmin: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        game = try container.decode(HaulonautGame.self, forKey: .game)
        instances = try container.decodeIfPresent([HaulonautInstance].self, forKey: .instances) ?? []
        characters = try container.decodeIfPresent([HaulonautCharacter].self, forKey: .characters) ?? []
        isAdmin = try container.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false
    }
}

struct HaulonautCreateCharacterResponse: Codable {
    let character: HaulonautCharacter
}

struct HaulonautCharacterSnapshotResponse: Codable {
    let character: HaulonautCharacter
    let currentSector: HaulonautSector?
    let connectedSectors: [HaulonautConnectedSector]
    let features: [HaulonautSectorFeature]
    let playersHere: [HaulonautPlayerHere]
    let credits: Int
    let rations: Int
    let fuel: Int
    let health: Int
    let cycles: Int
    let cyclesUpdatedAt: Int
    let inventory: [HaulonautInventoryItem]
    // Which planet feature the ship is landed at (null = in open space)
    let dockedFeatureId: Int?
    // True once the pilot has exited the craft onto the surface
    let onSurface: Bool
    // Populated only when onSurface is true
    let surfaceMap: HaulonautSurfaceMap?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        character = try container.decode(HaulonautCharacter.self, forKey: .character)
        currentSector = try container.decodeIfPresent(HaulonautSector.self, forKey: .currentSector)
        connectedSectors = try container.decodeIfPresent([HaulonautConnectedSector].self, forKey: .connectedSectors) ?? []
        features = try container.decodeIfPresent([HaulonautSectorFeature].self, forKey: .features) ?? []
        playersHere = try container.decodeIfPresent([HaulonautPlayerHere].self, forKey: .playersHere) ?? []
        credits = try container.decodeIfPresent(Int.self, forKey: .credits) ?? 0
        rations = try container.decodeIfPresent(Int.self, forKey: .rations) ?? 0
        fuel = try container.decodeIfPresent(Int.self, forKey: .fuel) ?? 0
        health = try container.decodeIfPresent(Int.self, forKey: .health) ?? 100
        cycles = try container.decodeIfPresent(Int.self, forKey: .cycles) ?? 0
        cyclesUpdatedAt = try container.decodeIfPresent(Int.self, forKey: .cyclesUpdatedAt) ?? 0
        inventory = try container.decodeIfPresent([HaulonautInventoryItem].self, forKey: .inventory) ?? []
        dockedFeatureId = try container.decodeIfPresent(Int.self, forKey: .dockedFeatureId)
        onSurface = try container.decodeIfPresent(Bool.self, forKey: .onSurface) ?? false
        surfaceMap = try container.decodeIfPresent(HaulonautSurfaceMap.self, forKey: .surfaceMap)
    }
}

struct HaulonautNavigateResponse: Codable {
    let currentSector: HaulonautSector?
    let connectedSectors: [HaulonautConnectedSector]
    let features: [HaulonautSectorFeature]
    let playersHere: [HaulonautPlayerHere]
    let credits: Int
    let rations: Int
    let fuel: Int
    let health: Int
    let cycles: Int
    let cyclesUpdatedAt: Int
    // True only when this warp's starvation damage just dropped crew health to 0
    let died: Bool
    // Warping always undocks server-side
    let dockedFeatureId: Int?
    let onSurface: Bool
    let surfaceMap: HaulonautSurfaceMap?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentSector = try container.decodeIfPresent(HaulonautSector.self, forKey: .currentSector)
        connectedSectors = try container.decodeIfPresent([HaulonautConnectedSector].self, forKey: .connectedSectors) ?? []
        features = try container.decodeIfPresent([HaulonautSectorFeature].self, forKey: .features) ?? []
        playersHere = try container.decodeIfPresent([HaulonautPlayerHere].self, forKey: .playersHere) ?? []
        credits = try container.decodeIfPresent(Int.self, forKey: .credits) ?? 0
        rations = try container.decodeIfPresent(Int.self, forKey: .rations) ?? 0
        fuel = try container.decodeIfPresent(Int.self, forKey: .fuel) ?? 0
        health = try container.decodeIfPresent(Int.self, forKey: .health) ?? 100
        cycles = try container.decodeIfPresent(Int.self, forKey: .cycles) ?? 0
        cyclesUpdatedAt = try container.decodeIfPresent(Int.self, forKey: .cyclesUpdatedAt) ?? 0
        died = try container.decodeIfPresent(Bool.self, forKey: .died) ?? false
        dockedFeatureId = try container.decodeIfPresent(Int.self, forKey: .dockedFeatureId)
        onSurface = try container.decodeIfPresent(Bool.self, forKey: .onSurface) ?? false
        surfaceMap = try container.decodeIfPresent(HaulonautSurfaceMap.self, forKey: .surfaceMap)
    }
}

struct HaulonautItemsResponse: Codable {
    let items: [HaulonautItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([HaulonautItem].self, forKey: .items) ?? []
    }
}

struct HaulonautPurchaseResponse: Codable {
    let message: String
    let credits: Int
    let rations: Int
    let fuel: Int
    let health: Int
    let cycles: Int
    let cyclesUpdatedAt: Int
    let inventory: [HaulonautInventoryItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decode(String.self, forKey: .message)
        credits = try container.decode(Int.self, forKey: .credits)
        rations = try container.decode(Int.self, forKey: .rations)
        fuel = try container.decodeIfPresent(Int.self, forKey: .fuel) ?? 0
        health = try container.decodeIfPresent(Int.self, forKey: .health) ?? 100
        cycles = try container.decodeIfPresent(Int.self, forKey: .cycles) ?? 0
        cyclesUpdatedAt = try container.decodeIfPresent(Int.self, forKey: .cyclesUpdatedAt) ?? 0
        inventory = try container.decodeIfPresent([HaulonautInventoryItem].self, forKey: .inventory) ?? []
    }
}

// MARK: - API Request Bodies

struct HaulonautCreateCharacterRequest: Encodable {
    let displayName: String
    let instanceId: Int

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case instanceId = "instance_id"
    }
}

struct HaulonautNavigateRequest: Encodable {
    let toSectorId: Int

    enum CodingKeys: String, CodingKey {
        case toSectorId = "to_sector_id"
    }
}

struct HaulonautPurchaseRequest: Encodable {
    let itemKey: String
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case itemKey = "item_key"
        case quantity
    }
}

struct HaulonautDriveBuggyRequest: Encodable {
    let direction: String
}

// MARK: - Star Charts Models

/// A discovered location (planet, outpost, etc.) with distance from current sector.
struct HaulonautKnownLocation: Codable, Identifiable {
    let id: Int
    let sectorId: Int
    let sectorNumber: Int
    let featureType: String
    let name: String
    let distance: Int

    enum CodingKeys: String, CodingKey {
        case id
        case sectorId = "sector_id"
        case sectorNumber = "sector_number"
        case featureType = "feature_type"
        case name
        case distance
    }
}

struct HaulonautKnownLocationsResponse: Codable {
    let locations: [HaulonautKnownLocation]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        locations = try container.decodeIfPresent([HaulonautKnownLocation].self, forKey: .locations) ?? []
    }
}

/// A waypoint in an autopilot route.
struct HaulonautRouteWaypoint: Codable, Identifiable {
    let id: Int
    let sectorNumber: Int

    enum CodingKeys: String, CodingKey {
        case id
        case sectorNumber = "sector_number"
    }
}

struct HaulonautRouteResponse: Codable {
    let path: [HaulonautRouteWaypoint]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decodeIfPresent([HaulonautRouteWaypoint].self, forKey: .path) ?? []
    }
}

// MARK: - Drift Response

/// Response from POST /drift — uncontrolled movement toward nearest planet when fuel is 0.
struct HaulonautDriftResponse: Codable {
    let currentSector: HaulonautSector?
    let connectedSectors: [HaulonautConnectedSector]
    let features: [HaulonautSectorFeature]
    let playersHere: [HaulonautPlayerHere]
    let credits: Int
    let rations: Int
    let fuel: Int
    let health: Int
    let cycles: Int
    let cyclesUpdatedAt: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentSector = try container.decodeIfPresent(HaulonautSector.self, forKey: .currentSector)
        connectedSectors = try container.decodeIfPresent([HaulonautConnectedSector].self, forKey: .connectedSectors) ?? []
        features = try container.decodeIfPresent([HaulonautSectorFeature].self, forKey: .features) ?? []
        playersHere = try container.decodeIfPresent([HaulonautPlayerHere].self, forKey: .playersHere) ?? []
        credits = try container.decodeIfPresent(Int.self, forKey: .credits) ?? 0
        rations = try container.decodeIfPresent(Int.self, forKey: .rations) ?? 0
        fuel = try container.decodeIfPresent(Int.self, forKey: .fuel) ?? 0
        health = try container.decodeIfPresent(Int.self, forKey: .health) ?? 100
        cycles = try container.decodeIfPresent(Int.self, forKey: .cycles) ?? 0
        cyclesUpdatedAt = try container.decodeIfPresent(Int.self, forKey: .cyclesUpdatedAt) ?? 0
    }
}

// MARK: - Cycles Response

/// GET /cycles — lightweight re-sync for cycle balance after backgrounding.
struct HaulonautCyclesResponse: Codable {
    let cycles: Int
    let cyclesUpdatedAt: Int
    let maxCycles: Int
    let replenishSeconds: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cycles = try container.decodeIfPresent(Int.self, forKey: .cycles) ?? 0
        cyclesUpdatedAt = try container.decodeIfPresent(Int.self, forKey: .cyclesUpdatedAt) ?? 0
        maxCycles = try container.decodeIfPresent(Int.self, forKey: .maxCycles) ?? 24
        replenishSeconds = try container.decodeIfPresent(Int.self, forKey: .replenishSeconds) ?? 3600
    }
}

// MARK: - Docking Responses

/// POST /dock — returned when landing on a planet. Only carries cycle fields.
struct HaulonautDockResponse: Codable {
    let dockedFeatureId: Int?
    let cycles: Int
    let cyclesUpdatedAt: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dockedFeatureId = try container.decodeIfPresent(Int.self, forKey: .dockedFeatureId)
        cycles = try container.decodeIfPresent(Int.self, forKey: .cycles) ?? 0
        cyclesUpdatedAt = try container.decodeIfPresent(Int.self, forKey: .cyclesUpdatedAt) ?? 0
    }
}

/// POST /launch and POST /return-to-ship both acknowledge with success/message.
struct HaulonautActionAck: Codable {
    let success: Bool
    let message: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? false
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

/// POST /exit-craft — steps onto the surface, returns the surface map.
struct HaulonautExitCraftResponse: Codable {
    let dockedFeatureId: Int?
    let surfaceMap: HaulonautSurfaceMap?
    let cycles: Int
    let cyclesUpdatedAt: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dockedFeatureId = try container.decodeIfPresent(Int.self, forKey: .dockedFeatureId)
        surfaceMap = try container.decodeIfPresent(HaulonautSurfaceMap.self, forKey: .surfaceMap)
        cycles = try container.decodeIfPresent(Int.self, forKey: .cycles) ?? 0
        cyclesUpdatedAt = try container.decodeIfPresent(Int.self, forKey: .cyclesUpdatedAt) ?? 0
    }
}

/// POST /drive-buggy — one cell of movement on the surface.
struct HaulonautDriveBuggyResponse: Codable {
    let buggyX: Int
    let buggyY: Int
    let revealed: [Int]
    let atShip: Bool
    // Present only when the move reached a cell for the first time
    let narration: String?
    let effects: HaulonautLandingEffects?
    let cycles: Int
    let cyclesUpdatedAt: Int
    // Post-event resource totals (present only when effects are applied)
    let credits: Int?
    let rations: Int?
    let fuel: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        buggyX = try container.decodeIfPresent(Int.self, forKey: .buggyX) ?? 0
        buggyY = try container.decodeIfPresent(Int.self, forKey: .buggyY) ?? 0
        revealed = try container.decodeIfPresent([Int].self, forKey: .revealed) ?? []
        atShip = try container.decodeIfPresent(Bool.self, forKey: .atShip) ?? false
        narration = try container.decodeIfPresent(String.self, forKey: .narration)
        effects = try container.decodeIfPresent(HaulonautLandingEffects.self, forKey: .effects)
        cycles = try container.decodeIfPresent(Int.self, forKey: .cycles) ?? 0
        cyclesUpdatedAt = try container.decodeIfPresent(Int.self, forKey: .cyclesUpdatedAt) ?? 0
        credits = try container.decodeIfPresent(Int.self, forKey: .credits)
        rations = try container.decodeIfPresent(Int.self, forKey: .rations)
        fuel = try container.decodeIfPresent(Int.self, forKey: .fuel)
    }
}
