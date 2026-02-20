import Foundation
import SwiftUI

@MainActor
@Observable
final class BreakroomViewModel {
    var blocks: [BreakroomBlock] = []
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var expandedBlockIds: Set<Int> = []
    var showAddBlockSheet = false

    func loadLayout() async {
        isLoading = blocks.isEmpty
        errorMessage = nil

        do {
            blocks = try await BreakroomAPIService.getLayout()
            // Expand all blocks by default on first load
            if expandedBlockIds.isEmpty {
                expandedBlockIds = Set(blocks.map(\.id))
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        isRefreshing = true
        do {
            blocks = try await BreakroomAPIService.getLayout()
        } catch {
            errorMessage = error.localizedDescription
        }
        isRefreshing = false
    }

    func toggleBlock(_ id: Int) {
        if expandedBlockIds.contains(id) {
            expandedBlockIds.remove(id)
        } else {
            expandedBlockIds.insert(id)
        }
    }

    func isExpanded(_ id: Int) -> Bool {
        expandedBlockIds.contains(id)
    }

    func removeBlock(_ id: Int) async {
        let original = blocks
        blocks.removeAll { $0.id == id }
        expandedBlockIds.remove(id)

        do {
            try await BreakroomAPIService.removeBlock(id: id)
        } catch {
            blocks = original
            errorMessage = error.localizedDescription
        }
    }

    func addBlock(type: BlockType, title: String?, contentId: Int? = nil) async {
        do {
            let block = try await BreakroomAPIService.addBlock(type: type, title: title, contentId: contentId)
            withAnimation {
                blocks.append(block)
                expandedBlockIds.insert(block.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
