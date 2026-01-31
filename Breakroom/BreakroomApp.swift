import SwiftUI

@main
struct BreakroomApp: App {
    @State private var authViewModel = AuthViewModel()
    @State private var socketManager = ChatSocketManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authViewModel)
                .environment(socketManager)
        }
    }
}
