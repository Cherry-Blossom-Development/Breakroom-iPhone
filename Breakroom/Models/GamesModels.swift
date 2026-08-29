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
    let inventory: [HaulonautInventoryItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        character = try container.decode(HaulonautCharacter.self, forKey: .character)
        currentSector = try container.decodeIfPresent(HaulonautSector.self, forKey: .currentSector)
        connectedSectors = try container.decodeIfPresent([HaulonautConnectedSector].self, forKey: .connectedSectors) ?? []
        features = try container.decodeIfPresent([HaulonautSectorFeature].self, forKey: .features) ?? []
        playersHere = try container.decodeIfPresent([HaulonautPlayerHere].self, forKey: .playersHere) ?? []
        credits = try container.decodeIfPresent(Int.self, forKey: .credits) ?? 0
        rations = try container.decodeIfPresent(Int.self, forKey: .rations) ?? 0
        inventory = try container.decodeIfPresent([HaulonautInventoryItem].self, forKey: .inventory) ?? []
    }
}

struct HaulonautNavigateResponse: Codable {
    let currentSector: HaulonautSector?
    let connectedSectors: [HaulonautConnectedSector]
    let features: [HaulonautSectorFeature]
    let playersHere: [HaulonautPlayerHere]
    let credits: Int
    let rations: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentSector = try container.decodeIfPresent(HaulonautSector.self, forKey: .currentSector)
        connectedSectors = try container.decodeIfPresent([HaulonautConnectedSector].self, forKey: .connectedSectors) ?? []
        features = try container.decodeIfPresent([HaulonautSectorFeature].self, forKey: .features) ?? []
        playersHere = try container.decodeIfPresent([HaulonautPlayerHere].self, forKey: .playersHere) ?? []
        credits = try container.decodeIfPresent(Int.self, forKey: .credits) ?? 0
        rations = try container.decodeIfPresent(Int.self, forKey: .rations) ?? 0
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
    let inventory: [HaulonautInventoryItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decode(String.self, forKey: .message)
        credits = try container.decode(Int.self, forKey: .credits)
        rations = try container.decode(Int.self, forKey: .rations)
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
