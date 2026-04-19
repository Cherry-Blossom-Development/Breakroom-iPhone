import UIKit
import FirebaseMessaging
import UserNotifications
import os

private let pushLogger = Logger(subsystem: "com.cherryblossomdev.Breakroom", category: "PushNotificationManager")

@MainActor
@Observable
final class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()

    private(set) var fcmToken: String?
    private(set) var permissionStatus: UNAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        Task {
            await checkPermissionStatus()
        }
    }

    // MARK: - Permissions

    func requestPermissions() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await checkPermissionStatus()

            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                pushLogger.info("Push notification permissions granted")
            } else {
                pushLogger.info("Push notification permissions denied")
            }

            return granted
        } catch {
            pushLogger.error("Failed to request push notification permissions: \(error.localizedDescription)")
            return false
        }
    }

    private func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionStatus = settings.authorizationStatus
    }

    // MARK: - Notification Clearing

    /// Clears all delivered notifications and resets the app badge
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
        pushLogger.info("Cleared all notifications and badge")
    }

    /// Clears the app badge only
    func clearBadge() {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    // MARK: - Token Management

    func handleNewToken(_ token: String) {
        pushLogger.info("Received new FCM token")
        fcmToken = token
    }

    func registerTokenWithServer() async {
        guard let token = fcmToken else {
            pushLogger.warning("No FCM token available to register")
            return
        }

        pushLogger.warning("Registering FCM token: \(token.prefix(20))...")
        do {
            try await FCMAPIService.registerToken(token)
            pushLogger.warning("FCM token registered with server successfully!")
        } catch {
            pushLogger.error("Failed to register FCM token: \(String(describing: error))")
        }
    }

    func unregisterToken() async {
        guard let token = fcmToken else {
            pushLogger.warning("No FCM token available to unregister")
            return
        }

        do {
            try await FCMAPIService.removeToken(token)
            pushLogger.info("FCM token unregistered from server")
        } catch {
            pushLogger.error("Failed to unregister FCM token: \(error.localizedDescription)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification banner in foreground
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Extract values synchronously before any async work
        let type = userInfo["type"] as? String
        let roomId = (userInfo["roomId"] as? String).flatMap { Int($0) }
        let postId = (userInfo["postId"] as? String).flatMap { Int($0) }

        Task { @MainActor in
            self.handleNotificationTap(type: type, roomId: roomId, postId: postId)
        }

        completionHandler()
    }

    func handleNotificationTap(type: String?, roomId: Int?, postId: Int?) {
        guard let type else { return }

        switch type {
        case "chat_message":
            if let roomId {
                pushLogger.info("Should navigate to chat room: \(roomId)")
            }
        case "friend_request":
            pushLogger.info("Should navigate to friends screen")
        case "blog_comment":
            if let postId {
                pushLogger.info("Should navigate to blog post: \(postId)")
            }
        default:
            pushLogger.info("Unknown notification type: \(type)")
        }
    }
}

// MARK: - MessagingDelegate

extension PushNotificationManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("[PUSH DEBUG] MessagingDelegate received token: \(fcmToken?.prefix(20) ?? "nil")...")
        guard let token = fcmToken else { return }

        Task { @MainActor in
            self.handleNewToken(token)

            // If user is already logged in, register the new token
            let isLoggedIn = KeychainManager.token != nil
            print("[PUSH DEBUG] User logged in: \(isLoggedIn)")
            if isLoggedIn {
                await self.registerTokenWithServer()
            }
        }
    }
}

// MARK: - FCM API Service

enum FCMAPIService {
    static func registerToken(_ fcmToken: String) async throws {
        let body = FCMTokenRequest(fcmToken: fcmToken)
        pushLogger.warning("Making POST to /api/auth/fcm-token with token: \(fcmToken.prefix(20))...")
        do {
            try await APIClient.shared.requestVoid(
                "/api/auth/fcm-token",
                method: "POST",
                body: body
            )
            pushLogger.warning("POST /api/auth/fcm-token succeeded!")
        } catch {
            pushLogger.error("POST /api/auth/fcm-token failed: \(String(describing: error))")
            throw error
        }
    }

    static func removeToken(_ fcmToken: String) async throws {
        let body = FCMTokenRequest(fcmToken: fcmToken)
        try await APIClient.shared.requestVoid(
            "/api/auth/fcm-token",
            method: "DELETE",
            body: body
        )
    }
}

private struct FCMTokenRequest: Encodable {
    let fcmToken: String
}
