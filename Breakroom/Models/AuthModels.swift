import Foundation

struct LoginRequest: Encodable {
    let handle: String
    let password: String
}

struct SignupRequest: Encodable {
    let handle: String
    let firstName: String
    let lastName: String
    let email: String
    let hash: String
    let salt: String

    enum CodingKeys: String, CodingKey {
        case handle
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case hash
        case salt
    }
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

// MARK: - Forgot Password

struct ForgotPasswordRequest: Encodable {
    let email: String
}

struct ForgotPasswordResponse: Decodable {
    let message: String
}

struct ResetPasswordRequest: Encodable {
    let token: String
    let password: String
    let salt: String
    let hash: String
}

struct ResetPasswordResponse: Decodable {
    let message: String
}

// MARK: - EULA

struct EulaStatusResponse: Decodable {
    let accepted: Bool
    let notificationId: Int?
    let acceptedAt: String?
}

struct NotificationStatusRequest: Encodable {
    let status: String
}

struct NotificationStatusResponse: Decodable {
    let message: String
}
