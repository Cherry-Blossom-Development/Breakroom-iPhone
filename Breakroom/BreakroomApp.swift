import SwiftUI

@main
struct BreakroomApp: App {
    @State private var authViewModel = AuthViewModel()
    @State private var socketManager = ChatSocketManager()
    @State private var moderationStore = ModerationStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authViewModel)
                .environment(socketManager)
                .environment(moderationStore)
        }
    }
}
