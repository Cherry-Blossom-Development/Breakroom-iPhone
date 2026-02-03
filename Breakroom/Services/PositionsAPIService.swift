import Foundation

enum PositionsAPIService {
    static func getPositions() async throws -> [Position] {
        let response: PositionsResponse = try await APIClient.shared.request("/api/positions")
        return response.positions
    }

    static func getPosition(id: Int) async throws -> Position {
        let response: PositionDetailResponse = try await APIClient.shared.request("/api/positions/\(id)")
        return response.position
    }
}
