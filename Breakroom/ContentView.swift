import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(ChatSocketManager.self) private var socketManager

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                socketManager.connect()
            } else {
                socketManager.disconnect()
            }
        }
    }
}

struct MainTabView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var selectedTab = 0
    @State private var showBlogManagement = false
    @State private var showProfile = false
    @State private var showFriends = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                BreakroomView()
                    .navigationDestination(isPresented: $showBlogManagement) {
                        BlogManagementView()
                    }
                    .navigationDestination(isPresented: $showProfile) {
                        ProfileView()
                    }
                    .navigationDestination(isPresented: $showFriends) {
                        FriendsView()
                    }
                    .navigationTitle("Breakroom")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Menu {
                                Button("Profile", systemImage: "person") {
                                    showProfile = true
                                }
                                Button("Chat", systemImage: "bubble.left.and.bubble.right") {
                                    selectedTab = 1
                                }
                                Button("Friends", systemImage: "person.2") {
                                    showFriends = true
                                }
                                Button("Blog", systemImage: "doc.richtext") {
                                    showBlogManagement = true
                                }
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

            EmploymentView()
                .tabItem { Label("Employment", systemImage: "briefcase") }
                .tag(2)

            NavigationStack {
                CompanyPortalView()
            }
            .tabItem { Label("Company", systemImage: "building.2") }
            .tag(3)

            ToolShedView()
                .tabItem { Label("Tool Shed", systemImage: "wrench.and.screwdriver") }
                .tag(4)
        }
    }
}
