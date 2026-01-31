import Foundation

@MainActor
@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var currentUserId: Int?
    var currentUsername: String?
    var isLoading = false
    var errorMessage: String?

    init() {
        // Check for existing session on launch
        if KeychainManager.token != nil {
            Task { await checkExistingSession() }
        }
    }

    func login(handle: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let me = try await AuthService.login(handle: handle, password: password)
            currentUserId = me.userId
            currentUsername = me.username
            isAuthenticated = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signup(handle: String, name: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let me = try await AuthService.signup(
                handle: handle,
                name: name,
                email: email,
                password: password
            )
            currentUserId = me.userId
            currentUsername = me.username
            isAuthenticated = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func logout() async {
        await AuthService.logout()
        isAuthenticated = false
        currentUserId = nil
        currentUsername = nil
    }

    private func checkExistingSession() async {
        if let me = await AuthService.checkSession() {
            currentUserId = me.userId
            currentUsername = me.username
            isAuthenticated = true
        } else {
            KeychainManager.clearAll()
        }
    }
}
