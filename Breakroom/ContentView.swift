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

    // Shortcuts
    @State private var shortcuts: [Shortcut] = []
    @State private var selectedShortcut: Shortcut?

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
                    .navigationDestination(item: $selectedShortcut) { shortcut in
                        shortcutDestination(shortcut)
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

                                if !shortcuts.isEmpty {
                                    Divider()
                                    Section("Shortcuts") {
                                        ForEach(shortcuts) { shortcut in
                                            Button {
                                                handleShortcut(shortcut)
                                            } label: {
                                                Label(shortcut.name, systemImage: shortcutIcon(for: shortcut.url))
                                            }
                                        }
                                    }
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
                    .task {
                        await loadShortcuts()
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

    private func loadShortcuts() async {
        do {
            shortcuts = try await ShortcutsAPIService.getShortcuts()
        } catch {
            // Silently fail - shortcuts are optional
        }
    }

    private func handleShortcut(_ shortcut: Shortcut) {
        // Route to appropriate tab or view based on URL
        switch shortcut.url {
        case "/lyrics":
            selectedTab = 4 // Tool Shed tab
            selectedShortcut = shortcut
        case "/art-gallery":
            selectedTab = 4
            selectedShortcut = shortcut
        case "/blog":
            showBlogManagement = true
        case "/kanban":
            selectedTab = 3 // Company tab
        default:
            // For project shortcuts like /project/123
            if shortcut.url.hasPrefix("/project/") {
                selectedTab = 3 // Company tab
            } else {
                selectedShortcut = shortcut
            }
        }
    }

    private func shortcutIcon(for url: String) -> String {
        switch url {
        case "/lyrics":
            return "music.mic"
        case "/art-gallery":
            return "photo.artframe"
        case "/blog":
            return "doc.richtext"
        case "/kanban":
            return "rectangle.split.3x1"
        default:
            if url.hasPrefix("/project/") {
                return "rectangle.split.3x1"
            }
            return "bookmark"
        }
    }

    @ViewBuilder
    private func shortcutDestination(_ shortcut: Shortcut) -> some View {
        switch shortcut.url {
        case "/lyrics":
            LyricLabView()
        case "/art-gallery":
            Text("Art Gallery - Coming Soon")
        default:
            Text("Shortcut: \(shortcut.name)")
        }
    }
}
