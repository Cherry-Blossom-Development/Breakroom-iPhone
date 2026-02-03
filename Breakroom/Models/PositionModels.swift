import Foundation

struct Position: Identifiable {
    let id: Int
    let companyId: Int
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
    let status: String?
    let createdBy: Int?
    let createdAt: String?
    let companyName: String?
    let companyCity: String?
    let companyState: String?
    let companyDescription: String?
    let companyWebsite: String?
    let companyCountry: String?

    var formattedPay: String {
        guard payRateMin != nil || payRateMax != nil else { return "Negotiable" }

        let typeLabel: String = switch payType {
        case "hourly": "/hr"
        case "salary": "/yr"
        default: ""
        }

        if let min = payRateMin, let max = payRateMax {
            return "\(formatNumber(min)) - \(formatNumber(max))\(typeLabel)"
        } else if let min = payRateMin {
            return "\(formatNumber(min))+\(typeLabel)"
        } else if let max = payRateMax {
            return "Up to \(formatNumber(max))\(typeLabel)"
        }
        return "Negotiable"
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            let k = Double(n) / 1000.0
            return n % 1000 == 0 ? "$\(Int(k))k" : "$\(String(format: "%.1f", k))k"
        }
        return "$\(n)"
    }

    var formattedLocationType: String {
        guard let locationType, !locationType.isEmpty else { return "" }
        return locationType.prefix(1).uppercased() + locationType.dropFirst()
    }

    var formattedEmploymentType: String {
        guard let employmentType, !employmentType.isEmpty else { return "" }
        return employmentType.split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: "-")
    }

    var locationString: String {
        var parts: [String] = []
        if let city, !city.isEmpty { parts.append(city) }
        if let state, !state.isEmpty { parts.append(state) }
        if parts.isEmpty, let companyCity, !companyCity.isEmpty { parts.append(companyCity) }
        if parts.isEmpty, let companyState, !companyState.isEmpty { parts.append(companyState) }
        return parts.isEmpty ? "Location not specified" : parts.joined(separator: ", ")
    }

    var relativeDate: String {
        guard let dateString = createdAt else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: dateString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: dateString)
        }
        guard let date else { return "" }

        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days < 7 { return "\(days) days ago" }
        if days < 30 { return "\(days / 7) weeks ago" }

        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    var descriptionExcerpt: String {
        guard let description, !description.isEmpty else { return "" }
        if description.count <= 150 { return description }
        return String(description.prefix(150)) + "..."
    }
}

extension Position: Decodable {
    enum CodingKeys: String, CodingKey {
        case id
        case companyId = "company_id"
        case title, description, department
        case locationType = "location_type"
        case city, state, country
        case employmentType = "employment_type"
        case payRateMin = "pay_rate_min"
        case payRateMax = "pay_rate_max"
        case payType = "pay_type"
        case requirements, benefits, status
        case createdBy = "created_by"
        case createdAt = "created_at"
        case companyName = "company_name"
        case companyCity = "company_city"
        case companyState = "company_state"
        case companyDescription = "company_description"
        case companyWebsite = "company_website"
        case companyCountry = "company_country"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.flexInt(forKey: .id)
        companyId = try c.flexInt(forKey: .companyId)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        department = try c.decodeIfPresent(String.self, forKey: .department)
        locationType = try c.decodeIfPresent(String.self, forKey: .locationType)
        city = try c.decodeIfPresent(String.self, forKey: .city)
        state = try c.decodeIfPresent(String.self, forKey: .state)
        country = try c.decodeIfPresent(String.self, forKey: .country)
        employmentType = try c.decodeIfPresent(String.self, forKey: .employmentType)
        payRateMin = try c.flexIntIfPresent(forKey: .payRateMin)
        payRateMax = try c.flexIntIfPresent(forKey: .payRateMax)
        payType = try c.decodeIfPresent(String.self, forKey: .payType)
        requirements = try c.decodeIfPresent(String.self, forKey: .requirements)
        benefits = try c.decodeIfPresent(String.self, forKey: .benefits)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        createdBy = try c.flexIntIfPresent(forKey: .createdBy)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        companyName = try c.decodeIfPresent(String.self, forKey: .companyName)
        companyCity = try c.decodeIfPresent(String.self, forKey: .companyCity)
        companyState = try c.decodeIfPresent(String.self, forKey: .companyState)
        companyDescription = try c.decodeIfPresent(String.self, forKey: .companyDescription)
        companyWebsite = try c.decodeIfPresent(String.self, forKey: .companyWebsite)
        companyCountry = try c.decodeIfPresent(String.self, forKey: .companyCountry)
    }
}

// Handles JSON values that could be Int, Double, or String representations of numbers
private extension KeyedDecodingContainer {
    func flexInt(forKey key: Key) throws -> Int {
        if let v = try? decode(Int.self, forKey: key) { return v }
        if let v = try? decode(Double.self, forKey: key) { return Int(v) }
        if let s = try? decode(String.self, forKey: key), let v = Int(s) { return v }
        throw DecodingError.typeMismatch(Int.self, .init(codingPath: [key], debugDescription: "Expected numeric value"))
    }

    func flexIntIfPresent(forKey key: Key) throws -> Int? {
        guard contains(key), !(try decodeNil(forKey: key)) else { return nil }
        if let v = try? decode(Int.self, forKey: key) { return v }
        if let v = try? decode(Double.self, forKey: key) { return Int(v) }
        if let s = try? decode(String.self, forKey: key), let v = Int(s) { return v }
        return nil
    }
}

// MARK: - Response Types

struct PositionsResponse: Decodable {
    let positions: [Position]
}

struct PositionDetailResponse: Decodable {
    let position: Position
}
