import Foundation
import SocketIO

/// Socket.IO manager for Haulonaut game real-time events.
/// Handles sector-based communication: chat, arrivals, trades, combat, probes.
@MainActor
@Observable
final class HaulonautSocketManager {
    static let shared = HaulonautSocketManager()

    enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }

    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var currentSectorId: Int?
    private(set) var currentCharacterId: Int?

    private var manager: SocketIO.SocketManager?
    private var socket: SocketIOClient?

    // MARK: - Event Callbacks

    /// Called when a chat message is received in the sector
    var onSectorMessage: ((HaulonautSectorMessage) -> Void)?

    /// Called when a pilot enters the sector (id, displayName, isNpc)
    var onSectorArrival: ((Int, String, Bool) -> Void)?

    /// Called when receiving a token gift (fromDisplayName, credits)
    var onGiftReceived: ((String, Int) -> Void)?

    /// Called when receiving a trade offer
    var onTradeOffer: ((HaulonautTradeOfferSummary) -> Void)?

    /// Called when a trade is resolved (offerId, accepted)
    var onTradeResolved: ((Int, Bool) -> Void)?

    /// Called when a probe mission completes
    var onProbeReport: ((HaulonautProbeReport) -> Void)?

    /// Called when combat occurs in sector (attackerName, targetName, damage, targetDied)
    var onCombatEvent: ((String, String, Int, Bool) -> Void)?

    /// Called when a tracking buoy attaches to a target (buoyId, targetDisplayName)
    var onBuoyAttached: ((Int, String) -> Void)?

    // MARK: - Lifecycle

    private init() {}

    func connect(characterId: Int) {
        guard let token = KeychainManager.token else { return }
        guard connectionState == .disconnected else { return }

        currentCharacterId = characterId
        connectionState = .connecting

        let url = URL(string: Config.baseURL)!
        manager = SocketIO.SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .forceWebsockets(true),
            .reconnects(true),
            .reconnectAttempts(10),
            .reconnectWait(1),
            .connectParams(["token": token])
        ])

        guard let manager else { return }
        socket = manager.defaultSocket

        setupEventHandlers()
        socket?.connect()
    }

    func disconnect() {
        if let sectorId = currentSectorId {
            leaveSector(sectorId)
        }
        socket?.disconnect()
        socket = nil
        manager?.disconnect()
        manager = nil
        connectionState = .disconnected
        currentSectorId = nil
        currentCharacterId = nil
    }

    // MARK: - Sector Room Management

    func joinSector(_ sectorId: Int) {
        guard let characterId = currentCharacterId else { return }

        // Leave previous sector if any
        if let previousSectorId = currentSectorId, previousSectorId != sectorId {
            leaveSector(previousSectorId)
        }

        currentSectorId = sectorId
        socket?.emit("haulonaut_join_sector", ["characterId": characterId, "sectorId": sectorId])

        #if DEBUG
        print("[HaulonautSocket] Joined sector \(sectorId)")
        #endif
    }

    func leaveSector(_ sectorId: Int) {
        guard let characterId = currentCharacterId else { return }
        socket?.emit("haulonaut_leave_sector", ["characterId": characterId, "sectorId": sectorId])
        if currentSectorId == sectorId {
            currentSectorId = nil
        }

        #if DEBUG
        print("[HaulonautSocket] Left sector \(sectorId)")
        #endif
    }

    // MARK: - Sending Messages

    func sendSectorMessage(_ message: String) {
        guard let characterId = currentCharacterId,
              let sectorId = currentSectorId else { return }

        socket?.emit("haulonaut_sector_message", [
            "characterId": characterId,
            "sectorId": sectorId,
            "message": message
        ])
    }

    // MARK: - Event Handlers

    private func setupEventHandlers() {
        socket?.on(clientEvent: .connect) { [weak self] _, _ in
            Task { @MainActor in
                self?.connectionState = .connected
                #if DEBUG
                print("[HaulonautSocket] Connected")
                #endif

                // Rejoin sector if we had one
                if let sectorId = self?.currentSectorId {
                    self?.joinSector(sectorId)
                }
            }
        }

        socket?.on(clientEvent: .disconnect) { [weak self] _, _ in
            Task { @MainActor in
                self?.connectionState = .disconnected
                #if DEBUG
                print("[HaulonautSocket] Disconnected")
                #endif
            }
        }

        socket?.on(clientEvent: .reconnect) { _, _ in
            #if DEBUG
            print("[HaulonautSocket] Reconnecting...")
            #endif
        }

        socket?.on(clientEvent: .error) { data, _ in
            #if DEBUG
            print("[HaulonautSocket] Error:", data)
            #endif
        }

        // Sector chat message
        socket?.on("haulonaut_sector_message") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let characterId = dict["characterId"] as? Int,
                  let displayName = dict["displayName"] as? String,
                  let message = dict["message"] as? String else {
                return
            }

            let sectorMessage = HaulonautSectorMessage(
                characterId: characterId,
                displayName: displayName,
                message: message
            )

            Task { @MainActor in
                self?.onSectorMessage?(sectorMessage)
            }
        }

        // Pilot entered sector
        socket?.on("haulonaut_sector_arrival") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let characterId = dict["characterId"] as? Int,
                  let displayName = dict["displayName"] as? String else {
                return
            }
            let isNpc = (dict["isNpc"] as? Int ?? 0) == 1

            Task { @MainActor in
                self?.onSectorArrival?(characterId, displayName, isNpc)
            }
        }

        // Gift received
        socket?.on("haulonaut_gift_received") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let fromDisplayName = dict["fromDisplayName"] as? String,
                  let credits = dict["credits"] as? Int else {
                return
            }

            Task { @MainActor in
                self?.onGiftReceived?(fromDisplayName, credits)
            }
        }

        // Trade offer received
        socket?.on("haulonaut_trade_offer") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let id = dict["id"] as? Int,
                  let fromGameUserId = dict["fromGameUserId"] as? Int,
                  let toGameUserId = dict["toGameUserId"] as? Int,
                  let quantity = dict["quantity"] as? Int,
                  let credits = dict["credits"] as? Int,
                  let itemKey = dict["itemKey"] as? String,
                  let itemName = dict["itemName"] as? String,
                  let fromDisplayName = dict["fromDisplayName"] as? String,
                  let toDisplayName = dict["toDisplayName"] as? String else {
                return
            }

            let offer = HaulonautTradeOfferSummary(
                id: id,
                fromGameUserId: fromGameUserId,
                toGameUserId: toGameUserId,
                quantity: quantity,
                credits: credits,
                createdAt: nil,
                itemKey: itemKey,
                itemName: itemName,
                fromDisplayName: fromDisplayName,
                toDisplayName: toDisplayName
            )

            Task { @MainActor in
                self?.onTradeOffer?(offer)
            }
        }

        // Trade resolved
        socket?.on("haulonaut_trade_resolved") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let offerId = dict["offerId"] as? Int,
                  let accepted = dict["accepted"] as? Bool else {
                return
            }

            Task { @MainActor in
                self?.onTradeResolved?(offerId, accepted)
            }
        }

        // Probe report
        socket?.on("haulonaut_probe_report") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let missionId = dict["missionId"] as? Int,
                  let missionType = dict["missionType"] as? String,
                  let status = dict["status"] as? String,
                  let summary = dict["summary"] as? String else {
                return
            }

            let report = HaulonautProbeReport(
                id: missionId,
                missionType: missionType,
                status: status,
                summary: summary
            )

            Task { @MainActor in
                self?.onProbeReport?(report)
            }
        }

        // Combat event
        socket?.on("haulonaut_combat_event") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let attackerName = dict["attackerName"] as? String,
                  let targetName = dict["targetName"] as? String,
                  let damage = dict["damage"] as? Int else {
                return
            }
            let targetDied = dict["targetDied"] as? Bool ?? false

            Task { @MainActor in
                self?.onCombatEvent?(attackerName, targetName, damage, targetDied)
            }
        }

        // Buoy attached event
        socket?.on("haulonaut_buoy_attached") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let buoyId = dict["buoyId"] as? Int,
                  let targetDisplayName = dict["targetDisplayName"] as? String else {
                return
            }

            Task { @MainActor in
                self?.onBuoyAttached?(buoyId, targetDisplayName)
            }
        }
    }
}
