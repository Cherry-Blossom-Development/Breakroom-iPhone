import Foundation

enum CompanyAPIService {
    static func searchCompanies(query: String) async throws -> [CompanySearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let response: CompanySearchResponse = try await APIClient.shared.request(
            "/api/company/search?q=\(encoded)"
        )
        return response.companies
    }

    static func getMyCompanies() async throws -> [MyCompany] {
        let response: MyCompaniesResponse = try await APIClient.shared.request(
            "/api/company/my/list"
        )
        return response.companies
    }

    static func getCompany(id: Int) async throws -> CompanyDetailResponse {
        try await APIClient.shared.request("/api/company/\(id)")
    }

    static func createCompany(
        name: String,
        description: String?,
        address: String?,
        city: String?,
        state: String?,
        country: String?,
        postalCode: String?,
        phone: String?,
        email: String?,
        website: String?,
        employeeTitle: String
    ) async throws -> CompanyDetail {
        let body = CreateCompanyRequest(
            name: name,
            description: description,
            address: address,
            city: city,
            state: state,
            country: country,
            postalCode: postalCode,
            phone: phone,
            email: email,
            website: website,
            employeeTitle: employeeTitle
        )
        let response: CreateCompanyResponse = try await APIClient.shared.request(
            "/api/company",
            method: "POST",
            body: body
        )
        return response.company
    }

    static func updateCompany(
        id: Int,
        name: String,
        description: String?,
        address: String?,
        city: String?,
        state: String?,
        country: String?,
        postalCode: String?,
        phone: String?,
        email: String?,
        website: String?
    ) async throws -> CompanyDetail {
        let body = UpdateCompanyRequest(
            name: name,
            description: description,
            address: address,
            city: city,
            state: state,
            country: country,
            postalCode: postalCode,
            phone: phone,
            email: email,
            website: website
        )
        let response: UpdateCompanyResponse = try await APIClient.shared.request(
            "/api/company/\(id)",
            method: "PUT",
            body: body
        )
        return response.company
    }
}
