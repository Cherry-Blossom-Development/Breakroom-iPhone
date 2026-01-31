import Foundation

struct LoginRequest: Encodable {
    let handle: String
    let password: String
}

struct SignupRequest: Encodable {
    let handle: String
    let name: String
    let email: String
    let hash: String
    let salt: String
}

struct AuthResponse: Decodable {
    let token: String
}

struct MeResponse: Decodable {
    let userId: Int
    let username: String
}

struct ErrorResponse: Decodable {
    let error: String?
    let message: String?

    var displayMessage: String {
        error ?? message ?? "An unknown error occurred"
    }
}
