import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(ChatSocketManager.self) private var socketManager
    @Environment(ModerationStore.self) private var moderationStore

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                if authViewModel.hasAcceptedEula {
                    MainTabView()
                } else {
                    EulaView {
                        authViewModel.markEulaAccepted()
                    }
                }
            } else {
                LoginView()
            }
        }
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                socketManager.connect()
                Task { await moderationStore.loadBlockList() }
            } else {
                socketManager.disconnect()
                moderationStore.clear()
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
    @State private var showLegal = false

    // Account deletion
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var showDeleteAccountError = false

    // Shortcuts
    @State private var shortcuts: [Shortcut] = []
    @State private var selectedShortcut: Shortcut?
    @State private var showManageShortcuts = false

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
                    .navigationDestination(isPresented: $showLegal) {
                        LegalView()
                    }
                    .navigationDestination(item: $selectedShortcut) { shortcut in
                        shortcutDestination(shortcut)
                    }
                    .navigationBarTitleDisplayMode(.inline)
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
                                Button("Legal", systemImage: "doc.text") {
                                    showLegal = true
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
                                        Button {
                                            showManageShortcuts = true
                                        } label: {
                                            Label("Manage Shortcuts", systemImage: "gear")
                                        }
                                    }
                                }

                                Divider()
                                Button("Logout", systemImage: "rectangle.portrait.and.arrow.right") {
                                    Task { await authViewModel.logout() }
                                }
                                Button("Delete Account", systemImage: "trash", role: .destructive) {
                                    showDeleteAccountConfirmation = true
                                }
                            } label: {
                                Image(systemName: "line.3.horizontal")
                            }
                        }
                        ToolbarItem(placement: .principal) {
                            HStack(spacing: 6) {
                                Image("Logo")
                                Text("Breakroom")
                                    .font(.headline)
                            }
                        }
                    }
                    .task {
                        await loadShortcuts()
                    }
            }
            .tabItem { Label("Breakroom", systemImage: "square.grid.2x2") }
            .tag(0)
            .accessibilityIdentifier("tabBreakroom")

            ChatListView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
                .tag(1)
                .accessibilityIdentifier("tabChat")

            EmploymentView()
                .tabItem { Label("Jobs", systemImage: "briefcase") }
                .tag(2)
                .accessibilityIdentifier("tabJobs")

            NavigationStack {
                CompanyPortalView()
            }
            .tabItem { Label("Company", systemImage: "building.2") }
            .tag(3)
            .accessibilityIdentifier("tabCompany")

            ToolShedView()
                .tabItem { Label("Tool Shed", systemImage: "wrench.and.screwdriver") }
                .tag(4)
                .accessibilityIdentifier("tabToolShed")
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: $showDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task { await performDeleteAccount() }
            }
        } message: {
            Text("Are you sure you want to permanently delete your account? This action cannot be undone and all your data will be removed.")
        }
        .alert("Error", isPresented: $showDeleteAccountError) {
            Button("OK") { }
        } message: {
            Text(deleteAccountError ?? "Failed to delete account")
        }
        .sheet(isPresented: $showManageShortcuts) {
            ManageShortcutsSheet(shortcuts: $shortcuts)
        }
    }

    private func performDeleteAccount() async {
        isDeletingAccount = true
        do {
            try await authViewModel.deleteAccount()
        } catch {
            deleteAccountError = error.localizedDescription
            showDeleteAccountError = true
        }
        isDeletingAccount = false
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
        case "/blog":
            showBlogManagement = true
        case "/kanban":
            selectedTab = 3 // Company tab
        default:
            // All other shortcuts navigate from Breakroom tab
            selectedShortcut = shortcut
        }
    }

    private func shortcutIcon(for url: String) -> String {
        switch url {
        case "/lyrics":
            return "music.mic"
        case "/sessions":
            return "music.note"
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
        case "/sessions":
            SessionsView()
        case "/art-gallery":
            ArtGalleryView()
        default:
            // Handle project shortcuts like /project/123
            if shortcut.url.hasPrefix("/project/"),
               let projectIdString = shortcut.url.split(separator: "/").last,
               let projectId = Int(projectIdString) {
                KanbanBoardView(projectId: projectId, projectTitle: shortcut.name)
            } else {
                Text("Shortcut: \(shortcut.name)")
            }
        }
    }
}

// MARK: - Manage Shortcuts Sheet

struct ManageShortcutsSheet: View {
    @Binding var shortcuts: [Shortcut]
    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting: Int?

    var body: some View {
        NavigationStack {
            List {
                if shortcuts.isEmpty {
                    ContentUnavailableView(
                        "No Shortcuts",
                        systemImage: "bookmark",
                        description: Text("Shortcuts you add will appear here.")
                    )
                } else {
                    ForEach(shortcuts) { shortcut in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(shortcut.name)
                                    .font(.body)
                                Text(shortcut.url)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isDeleting == shortcut.id {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await deleteShortcut(shortcut) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Manage Shortcuts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func deleteShortcut(_ shortcut: Shortcut) async {
        isDeleting = shortcut.id
        do {
            try await ShortcutsAPIService.deleteShortcut(id: shortcut.id)
            shortcuts.removeAll { $0.id == shortcut.id }
        } catch {
            // Silently fail
        }
        isDeleting = nil
    }
}
