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

        do {
            try await FCMAPIService.registerToken(token)
            pushLogger.info("FCM token registered with server")
        } catch {
            pushLogger.error("Failed to register FCM token: \(error.localizedDescription)")
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
        guard let token = fcmToken else { return }

        Task { @MainActor in
            self.handleNewToken(token)

            // If user is already logged in, register the new token
            if KeychainManager.token != nil {
                await self.registerTokenWithServer()
            }
        }
    }
}

// MARK: - FCM API Service

enum FCMAPIService {
    static func registerToken(_ fcmToken: String) async throws {
        let body = FCMTokenRequest(fcmToken: fcmToken, platform: "ios")
        try await APIClient.shared.requestVoid(
            "/api/auth/fcm-token",
            method: "POST",
            body: body
        )
    }

    static func removeToken(_ fcmToken: String) async throws {
        let body = FCMTokenRequest(fcmToken: fcmToken, platform: "ios")
        try await APIClient.shared.requestVoid(
            "/api/auth/fcm-token",
            method: "DELETE",
            body: body
        )
    }
}

private struct FCMTokenRequest: Encodable {
    let fcmToken: String
    let platform: String

    enum CodingKeys: String, CodingKey {
        case fcmToken = "fcm_token"
        case platform
    }
}
