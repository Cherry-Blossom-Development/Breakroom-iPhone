import SwiftUI
import FirebaseCore
import FirebaseMessaging
import os

private let appLogger = Logger(subsystem: "com.cherryblossomdev.Breakroom", category: "AppDelegate")

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        PushNotificationManager.shared.configure()

        // Always register for remote notifications
        appLogger.warning("Registering for remote notifications...")
        application.registerForRemoteNotifications()

        // Try to get FCM token directly after a short delay
        Task {
            try? await Task.sleep(for: .seconds(3))
            do {
                let fcmToken = try await Messaging.messaging().token()
                appLogger.warning("Direct FCM token fetch succeeded: \(fcmToken.prefix(20))...")
                await PushNotificationManager.shared.handleNewToken(fcmToken)
                if KeychainManager.token != nil {
                    appLogger.warning("User logged in, registering token...")
                    await PushNotificationManager.shared.registerTokenWithServer()
                }
            } catch {
                appLogger.error("Direct FCM token fetch FAILED: \(error.localizedDescription)")
            }
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        appLogger.warning("Got APNs token: \(tokenString.prefix(20))...")
        // Pass the APNs token to Firebase
        Messaging.messaging().apnsToken = deviceToken

        // Explicitly fetch FCM token
        Task {
            do {
                let fcmToken = try await Messaging.messaging().token()
                appLogger.warning("Got FCM token from APNs callback: \(fcmToken.prefix(20))...")
                await PushNotificationManager.shared.handleNewToken(fcmToken)
                if KeychainManager.token != nil {
                    await PushNotificationManager.shared.registerTokenWithServer()
                }
            } catch {
                appLogger.error("Failed to get FCM token: \(error.localizedDescription)")
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        appLogger.error("FAILED to register for remote notifications: \(error.localizedDescription)")
    }
}

@main
struct BreakroomApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var authViewModel = AuthViewModel()
    @State private var socketManager = ChatSocketManager()
    @State private var moderationStore = ModerationStore()
    @State private var badgeStore = BadgeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authViewModel)
                .environment(socketManager)
                .environment(moderationStore)
                .environment(badgeStore)
                .task {
                    // Request push notification permissions on launch
                    await PushNotificationManager.shared.requestPermissions()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Clear all notifications when app becomes active
                        PushNotificationManager.shared.clearAllNotifications()
                    }
                }
        }
    }
}
