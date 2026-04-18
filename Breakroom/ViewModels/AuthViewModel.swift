import Foundation
import os

private let authLogger = Logger(subsystem: "com.cherryblossomdev.Breakroom", category: "AuthViewModel")

@MainActor
@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var hasAcceptedEula = false
    var currentUserId: Int?
    var currentUsername: String?
    var isLoading = false
    var errorMessage: String?

    init() {
        #if DEBUG
        // Clear auth state when testing (triggered by launch argument)
        if UserDefaults.standard.bool(forKey: "CLEAR_AUTH_STATE") {
            KeychainManager.clearAll()
            UserDefaults.standard.removeObject(forKey: "CLEAR_AUTH_STATE")
        }
        #endif

        // Check for existing session on launch
        if KeychainManager.token != nil {
            Task { await checkExistingSession() }
        }

        // Listen for session expired notifications (401 responses)
        NotificationCenter.default.addObserver(
            forName: .sessionExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleSessionExpired()
            }
        }
    }

    /// Handle session expiration by logging out silently
    private func handleSessionExpired() async {
        guard isAuthenticated else { return }
        await logout()
    }

    func login(handle: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let me = try await AuthService.login(handle: handle, password: password)
            currentUserId = me.userId
            currentUsername = me.username
            isAuthenticated = true

            // Register FCM token for push notifications
            await PushNotificationManager.shared.registerTokenWithServer()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signup(handle: String, firstName: String, lastName: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let me = try await AuthService.signup(
                handle: handle,
                firstName: firstName,
                lastName: lastName,
                email: email,
                password: password
            )
            currentUserId = me.userId
            currentUsername = me.username
            isAuthenticated = true

            // Register FCM token for push notifications
            await PushNotificationManager.shared.registerTokenWithServer()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func logout() async {
        // Unregister FCM token before logging out
        await PushNotificationManager.shared.unregisterToken()

        await AuthService.logout()
        isAuthenticated = false
        hasAcceptedEula = false
        currentUserId = nil
        currentUsername = nil
    }

    func markEulaAccepted() {
        hasAcceptedEula = true
    }

    func deleteAccount() async throws {
        guard let userId = currentUserId else {
            throw APIError.unauthorized
        }
        try await AuthService.deleteAccount(userId: userId)
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
