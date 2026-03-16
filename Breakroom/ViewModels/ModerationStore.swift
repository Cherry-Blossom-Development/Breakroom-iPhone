import Foundation

/// App-level store holding the current user's block list.
/// Uses @Observable so any SwiftUI view reading from it will update when the list changes.
@MainActor
@Observable
final class ModerationStore {
    private(set) var blockedUserIds: Set<Int> = []
    private(set) var isLoaded = false

    func isBlocked(_ userId: Int) -> Bool {
        blockedUserIds.contains(userId)
    }

    func setBlockList(_ ids: [Int]) {
        blockedUserIds = Set(ids)
        isLoaded = true
    }

    func addBlock(_ userId: Int) {
        blockedUserIds.insert(userId)
    }

    func removeBlock(_ userId: Int) {
        blockedUserIds.remove(userId)
    }

    func clear() {
        blockedUserIds.removeAll()
        isLoaded = false
    }

    /// Load the block list from the API
    func loadBlockList() async {
        do {
            let ids = try await ModerationAPIService.getBlockList()
            setBlockList(ids)
        } catch {
            // Silently fail - block list is optional functionality
            isLoaded = true
        }
    }

    /// Block a user and update local state
    func blockUser(_ userId: Int) async throws {
        try await ModerationAPIService.blockUser(userId: userId)
        addBlock(userId)
    }

    /// Unblock a user and update local state
    func unblockUser(_ userId: Int) async throws {
        try await ModerationAPIService.unblockUser(userId: userId)
        removeBlock(userId)
    }
}
