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

    // MARK: - Company Position CRUD

    static func getCompanyPositions(companyId: Int) async throws -> [Position] {
        let response: PositionsResponse = try await APIClient.shared.request(
            "/api/positions/company/\(companyId)"
        )
        return response.positions
    }

    static func createPosition(
        companyId: Int,
        title: String,
        description: String?,
        department: String?,
        locationType: String?,
        city: String?,
        state: String?,
        country: String?,
        employmentType: String?,
        payRateMin: Int?,
        payRateMax: Int?,
        payType: String?,
        requirements: String?,
        benefits: String?
    ) async throws -> Position {
        let body = CreatePositionRequest(
            title: title,
            description: description,
            department: department,
            locationType: locationType,
            city: city,
            state: state,
            country: country,
            employmentType: employmentType,
            payRateMin: payRateMin,
            payRateMax: payRateMax,
            payType: payType,
            requirements: requirements,
            benefits: benefits
        )
        let response: CreatePositionResponse = try await APIClient.shared.request(
            "/api/positions/company/\(companyId)",
            method: "POST",
            body: body
        )
        return response.position
    }

    static func updatePosition(
        id: Int,
        title: String?,
        description: String?,
        department: String?,
        locationType: String?,
        city: String?,
        state: String?,
        country: String?,
        employmentType: String?,
        payRateMin: Int?,
        payRateMax: Int?,
        payType: String?,
        requirements: String?,
        benefits: String?,
        status: String?
    ) async throws -> Position {
        let body = UpdatePositionRequest(
            title: title,
            description: description,
            department: department,
            locationType: locationType,
            city: city,
            state: state,
            country: country,
            employmentType: employmentType,
            payRateMin: payRateMin,
            payRateMax: payRateMax,
            payType: payType,
            requirements: requirements,
            benefits: benefits,
            status: status
        )
        let response: PositionDetailResponse = try await APIClient.shared.request(
            "/api/positions/\(id)",
            method: "PUT",
            body: body
        )
        return response.position
    }

    static func deletePosition(id: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/positions/\(id)",
            method: "DELETE"
        )
    }
}
