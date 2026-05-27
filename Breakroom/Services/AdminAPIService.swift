import Foundation

enum AdminAPIService {

    /// Check if the current user has admin_access permission
    static func checkAdminAccess() async throws -> Bool {
        let response: PermissionCheckResponse = try await APIClient.shared.request(
            "/api/permissions/check/admin_access"
        )
        return response.hasPermission
    }

    /// Get all users (for impersonation list)
    static func getAllUsers() async throws -> [SearchUser] {
        let response: AllUsersResponse = try await APIClient.shared.request("/api/user/all")
        return response.users
    }

    /// Start impersonating a user
    /// - Returns: The impersonated user's handle
    static func startImpersonation(userId: Int) async throws -> String {
        // Save current token as admin token before impersonating
        guard let currentToken = KeychainManager.token else {
            throw APIError.unauthorized
        }

        let response: ImpersonateResponse = try await APIClient.shared.request(
            "/api/admin/impersonate/\(userId)",
            method: "POST"
        )

        // The server sets a cookie with the new token, but for mobile we need to handle it differently
        // The response should include the token, or we read it from the response header
        if let newToken = response.token {
            // Save admin token for later restoration
            KeychainManager.adminToken = currentToken
            // Replace current token with impersonation token
            KeychainManager.token = newToken
            // Save impersonated handle for display
            KeychainManager.impersonatedHandle = response.handle
        }

        return response.handle
    }

    /// Stop impersonating and restore admin session
    static func stopImpersonation() async throws {
        guard let adminToken = KeychainManager.adminToken else {
            throw APIError.serverError("Not currently impersonating")
        }

        struct StopRequest: Encodable {
            let adminToken: String
        }

        try await APIClient.shared.requestVoid(
            "/api/admin/impersonate/stop",
            method: "POST",
            body: StopRequest(adminToken: adminToken)
        )

        // Restore admin token
        KeychainManager.token = adminToken
        KeychainManager.clearImpersonation()
    }
}
