import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

struct MainTabView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                BreakroomView()
                    .navigationTitle("Breakroom")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Menu {
                                Button("Profile", systemImage: "person") { }
                                Button("Chat", systemImage: "bubble.left.and.bubble.right") {
                                    selectedTab = 1
                                }
                                Button("Friends", systemImage: "person.2") { }
                                Button("Blog", systemImage: "doc.richtext") { }
                                Divider()
                                Button("Logout", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                                    Task { await authViewModel.logout() }
                                }
                            } label: {
                                Image(systemName: "line.3.horizontal")
                            }
                        }
                    }
            }
            .tabItem { Label("Breakroom", systemImage: "square.grid.2x2") }
            .tag(0)

            ChatListView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
                .tag(1)

            NavigationStack {
                Text("Open Positions")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .navigationTitle("Positions")
            }
            .tabItem { Label("Positions", systemImage: "briefcase") }
            .tag(2)

            NavigationStack {
                Text("Company Portal")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .navigationTitle("Company")
            }
            .tabItem { Label("Company", systemImage: "building.2") }
            .tag(3)
        }
    }
}
