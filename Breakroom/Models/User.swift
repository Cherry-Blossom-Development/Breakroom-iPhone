import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let handle: String
    let name: String?
    let email: String?
    let bio: String?
    let city: String?
    let country: String?
    let timezone: String?
    let profilePhotoPath: String?
    let firstName: String?
    let lastName: String?

    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? handle : parts.joined(separator: " ")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case handle
        case name
        case email
        case bio
        case city
        case country
        case timezone
        case profilePhotoPath = "profile_photo_path"
        case firstName = "first_name"
        case lastName = "last_name"
    }
}
