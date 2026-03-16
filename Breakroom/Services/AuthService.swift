import Foundation
import CryptoKit

enum AuthService {
    static func login(handle: String, password: String) async throws -> MeResponse {
        let loginRequest = LoginRequest(handle: handle, password: password)
        let authResponse: AuthResponse = try await APIClient.shared.request(
            "/api/auth/login",
            method: "POST",
            body: loginRequest,
            authenticated: false
        )

        KeychainManager.token = authResponse.token
        KeychainManager.save(handle, for: .username)

        let me: MeResponse = try await APIClient.shared.request("/api/auth/me")
        KeychainManager.save(String(me.userId), for: .userId)

        return me
    }

    static func signup(handle: String, firstName: String, lastName: String, email: String, password: String) async throws -> MeResponse {
        let salt = generateSalt()
        let hash = hashPassword(password, salt: salt)

        let signupRequest = SignupRequest(
            handle: handle,
            firstName: firstName,
            lastName: lastName,
            email: email,
            hash: hash,
            salt: salt
        )

        let authResponse: AuthResponse = try await APIClient.shared.request(
            "/api/auth/signup",
            method: "POST",
            body: signupRequest,
            authenticated: false
        )

        KeychainManager.token = authResponse.token
        KeychainManager.save(handle, for: .username)

        let me: MeResponse = try await APIClient.shared.request("/api/auth/me")
        KeychainManager.save(String(me.userId), for: .userId)

        return me
    }

    static func logout() async {
        try? await APIClient.shared.requestVoid("/api/auth/logout", method: "POST")
        KeychainManager.clearAll()
    }

    static func deleteAccount(userId: Int) async throws {
        try await APIClient.shared.requestVoid("/api/user/\(userId)", method: "DELETE")
        KeychainManager.clearAll()
    }

    static func checkSession() async -> MeResponse? {
        guard KeychainManager.token != nil else { return nil }
        return try? await APIClient.shared.request("/api/auth/me")
    }

    // MARK: - Forgot Password

    static func forgotPassword(email: String) async throws {
        let request = ForgotPasswordRequest(email: email)
        let _: ForgotPasswordResponse = try await APIClient.shared.request(
            "/api/auth/forgot-password",
            method: "POST",
            body: request,
            authenticated: false
        )
    }

    static func resetPassword(token: String, password: String) async throws {
        let salt = generateSalt()
        let hash = hashPassword(password, salt: salt)

        let request = ResetPasswordRequest(
            token: token,
            password: password,
            salt: salt,
            hash: hash
        )
        let _: ResetPasswordResponse = try await APIClient.shared.request(
            "/api/auth/reset-password",
            method: "POST",
            body: request,
            authenticated: false
        )
    }

    // MARK: - EULA

    static func getEulaStatus() async throws -> EulaStatusResponse {
        try await APIClient.shared.request("/api/eula/status")
    }

    static func acceptEula(notificationId: Int) async throws {
        let request = NotificationStatusRequest(status: "dismissed")
        let _: NotificationStatusResponse = try await APIClient.shared.request(
            "/api/notification/\(notificationId)/status",
            method: "PUT",
            body: request
        )
    }

    // MARK: - Password Hashing

    private static func generateSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func hashPassword(_ password: String, salt: String) -> String {
        let input = "\(password)\(salt)"
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
