import Foundation

// MARK: - Company from search results

struct CompanySearchResult: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let city: String?
    let state: String?
    let country: String?

    var locationString: String {
        let parts = [city, state].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? "" : parts.joined(separator: ", ")
    }
}

// MARK: - My Company (includes employee role info)

struct MyCompany: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let city: String?
    let state: String?
    let title: String?
    let isOwner: Int?
    let isAdmin: Int?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, city, state, title, status
        case isOwner = "is_owner"
        case isAdmin = "is_admin"
    }

    var isOwnerBool: Bool { (isOwner ?? 0) != 0 }
    var isAdminBool: Bool { (isAdmin ?? 0) != 0 }

    var locationString: String {
        let parts = [city, state].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? "" : parts.joined(separator: ", ")
    }

    var roleBadge: String? {
        if isOwnerBool { return "Owner" }
        if isAdminBool { return "Admin" }
        return nil
    }
}

// MARK: - Full company detail

struct CompanyDetail: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let postalCode: String?
    let phone: String?
    let email: String?
    let website: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, address, city, state, country
        case postalCode = "postal_code"
        case phone, email, website
        case createdAt = "created_at"
    }

    var locationString: String {
        let parts = [city, state, country].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? "" : parts.joined(separator: ", ")
    }
}

// MARK: - Company Employee

struct CompanyEmployee: Codable, Identifiable {
    let id: Int
    let title: String?
    let department: String?
    let hireDate: String?
    let isOwner: Int?
    let isAdmin: Int?
    let status: String?
    let userId: Int?
    let handle: String?
    let firstName: String?
    let lastName: String?
    let photoPath: String?

    enum CodingKeys: String, CodingKey {
        case id, title, department, status, handle
        case hireDate = "hire_date"
        case isOwner = "is_owner"
        case isAdmin = "is_admin"
        case userId = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case photoPath = "photo_path"
    }

    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? (handle ?? "Unknown") : parts.joined(separator: " ")
    }

    var isOwnerBool: Bool { (isOwner ?? 0) != 0 }
    var isAdminBool: Bool { (isAdmin ?? 0) != 0 }

    var photoURL: URL? {
        guard let photoPath, !photoPath.isEmpty else { return nil }
        return URL(string: "\(APIClient.shared.baseURL)/api/uploads/\(photoPath)")
    }
}

// MARK: - User Role in Company

struct CompanyUserRole: Codable {
    let isOwner: Int?
    let isAdmin: Int?
    let title: String?

    enum CodingKeys: String, CodingKey {
        case isOwner = "is_owner"
        case isAdmin = "is_admin"
        case title
    }

    var isOwnerBool: Bool { (isOwner ?? 0) != 0 }
    var isAdminBool: Bool { (isAdmin ?? 0) != 0 }
}

// MARK: - Response Types

struct CompanySearchResponse: Decodable {
    let companies: [CompanySearchResult]
}

struct MyCompaniesResponse: Decodable {
    let companies: [MyCompany]
}

struct CompanyDetailResponse: Decodable {
    let company: CompanyDetail
    let employees: [CompanyEmployee]
    let userRole: CompanyUserRole?
}

struct CreateCompanyResponse: Decodable {
    let company: CompanyDetail
    let message: String?
}

// MARK: - Request Types

struct CreateCompanyRequest: Encodable {
    let name: String
    let description: String?
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let postalCode: String?
    let phone: String?
    let email: String?
    let website: String?
    let employeeTitle: String

    enum CodingKeys: String, CodingKey {
        case name, description, address, city, state, country
        case postalCode = "postal_code"
        case phone, email, website
        case employeeTitle = "employee_title"
    }
}

struct UpdateCompanyRequest: Encodable {
    let name: String
    let description: String?
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let postalCode: String?
    let phone: String?
    let email: String?
    let website: String?

    enum CodingKeys: String, CodingKey {
        case name, description, address, city, state, country
        case postalCode = "postal_code"
        case phone, email, website
    }
}

struct UpdateCompanyResponse: Decodable {
    let company: CompanyDetail
}

// MARK: - Employee Management

struct EmployeeSearchUser: Codable, Identifiable {
    let id: Int
    let handle: String?
    let firstName: String?
    let lastName: String?
    let email: String?
    let photoPath: String?

    enum CodingKeys: String, CodingKey {
        case id, handle, email
        case firstName = "first_name"
        case lastName = "last_name"
        case photoPath = "photo_path"
    }

    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? (handle ?? "Unknown") : parts.joined(separator: " ")
    }

    var photoURL: URL? {
        guard let photoPath, !photoPath.isEmpty else { return nil }
        return URL(string: "\(APIClient.shared.baseURL)/api/uploads/\(photoPath)")
    }
}

struct EmployeeSearchResponse: Decodable {
    let users: [EmployeeSearchUser]
}

struct AddEmployeeRequest: Encodable {
    let userId: Int
    let title: String
    let department: String?
    let isAdmin: Int
    let hireDate: String?

    enum CodingKeys: String, CodingKey {
        case title, department
        case userId = "user_id"
        case isAdmin = "is_admin"
        case hireDate = "hire_date"
    }
}

struct AddEmployeeResponse: Decodable {
    let employee: CompanyEmployee
}

struct UpdateEmployeeRequest: Encodable {
    let title: String?
    let department: String?
    let isAdmin: Int?
    let hireDate: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case title, department, status
        case isAdmin = "is_admin"
        case hireDate = "hire_date"
    }
}

struct UpdateEmployeeResponse: Decodable {
    let employee: CompanyEmployee
}

// MARK: - Position Management

struct CreatePositionRequest: Encodable {
    let title: String
    let description: String?
    let department: String?
    let locationType: String?
    let city: String?
    let state: String?
    let country: String?
    let employmentType: String?
    let payRateMin: Int?
    let payRateMax: Int?
    let payType: String?
    let requirements: String?
    let benefits: String?

    enum CodingKeys: String, CodingKey {
        case title, description, department, city, state, country, requirements, benefits
        case locationType = "location_type"
        case employmentType = "employment_type"
        case payRateMin = "pay_rate_min"
        case payRateMax = "pay_rate_max"
        case payType = "pay_type"
    }
}

struct CreatePositionResponse: Decodable {
    let position: Position
}

struct UpdatePositionRequest: Encodable {
    let title: String?
    let description: String?
    let department: String?
    let locationType: String?
    let city: String?
    let state: String?
    let country: String?
    let employmentType: String?
    let payRateMin: Int?
    let payRateMax: Int?
    let payType: String?
    let requirements: String?
    let benefits: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case title, description, department, city, state, country, requirements, benefits, status
        case locationType = "location_type"
        case employmentType = "employment_type"
        case payRateMin = "pay_rate_min"
        case payRateMax = "pay_rate_max"
        case payType = "pay_type"
    }
}

// MARK: - Company Projects

struct CompanyProject: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let description: String?
    let isDefault: Int?
    let isActive: Int?
    let isPublic: Int?
    let createdAt: String?
    let updatedAt: String?
    let ticketCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case isDefault = "is_default"
        case isActive = "is_active"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case ticketCount = "ticket_count"
    }

    var isDefaultBool: Bool { (isDefault ?? 0) != 0 }
    var isActiveBool: Bool { (isActive ?? 0) != 0 }
    var isPublicBool: Bool { (isPublic ?? 0) != 0 }
}

struct CreateProjectRequest: Encodable {
    let companyId: Int
    let title: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case title, description
        case companyId = "company_id"
    }
}

struct CreateProjectResponse: Decodable {
    let project: CompanyProject
}

struct UpdateProjectRequest: Encodable {
    let title: String?
    let description: String?
    let isActive: Bool?
    let isPublic: Bool?

    enum CodingKeys: String, CodingKey {
        case title, description
        case isActive = "is_active"
        case isPublic = "is_public"
    }
}

struct UpdateProjectResponse: Decodable {
    let project: CompanyProject
}

struct CompanyProjectsResponse: Decodable {
    let projects: [CompanyProject]
}
