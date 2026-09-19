import Foundation

/// Global online/offline status tracking for users.
/// Seeded on login from a full snapshot and kept live via socket events.
@MainActor
@Observable
final class PresenceManager {
    static let shared = PresenceManager()

    /// Online status by user ID. Users not in this dictionary are treated as offline.
    private(set) var online: [Int: Bool] = [:]

    private init() {}

    // MARK: - Public API

    /// Check if a user is currently online.
    func isOnline(_ userId: Int) -> Bool {
        online[userId] ?? false
    }

    /// Fetch the initial snapshot of all online users. Called once at login.
    func fetchOnline() async {
        do {
            let onlineIds = try await ProfileAPIService.getOnlineUserIds()
            for id in onlineIds {
                online[id] = true
            }
            #if DEBUG
            print("[Presence] Loaded \(onlineIds.count) online users")
            #endif
        } catch {
            #if DEBUG
            print("[Presence] Failed to fetch online status: \(error)")
            #endif
        }
    }

    /// Hydrate presence state from a list of users with is_online field.
    /// Safe to call repeatedly — later calls just overwrite with fresher data.
    func hydrate(users: [any PresenceHydratable]) {
        for user in users {
            if let isOnline = user.isOnline {
                online[user.id] = isOnline
            }
        }
    }

    /// Handle a socket presence_update event.
    func onPresenceUpdate(userId: Int, isOnline: Bool) {
        online[userId] = isOnline
        #if DEBUG
        print("[Presence] User \(userId) is now \(isOnline ? "online" : "offline")")
        #endif
    }

    /// Clear all presence state on logout.
    func reset() {
        online = [:]
    }
}

/// Protocol for objects that can be hydrated into the presence store.
protocol PresenceHydratable {
    var id: Int { get }
    var isOnline: Bool? { get }
}
