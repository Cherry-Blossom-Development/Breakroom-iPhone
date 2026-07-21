import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(ChatSocketManager.self) private var socketManager
    @Environment(ModerationStore.self) private var moderationStore
    @Environment(BadgeStore.self) private var badgeStore

    // Scheduled message warning state
    @State private var scheduledWarning: ScheduledMessageWarning?
    @State private var scheduledMissed: ScheduledMessageMissed?

    var body: some View {
        ZStack {
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

            // Scheduled message warning overlay
            if let warning = scheduledWarning {
                scheduledWarningOverlay(warning)
            }

            // Scheduled message missed overlay
            if let missed = scheduledMissed {
                scheduledMissedOverlay(missed)
            }
        }
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                socketManager.connect()
                setupBadgeHandlers()
                setupScheduledMessageHandlers()
                Task {
                    await moderationStore.loadBlockList()
                    await badgeStore.fetchAll()
                }
            } else {
                socketManager.disconnect()
                moderationStore.clear()
                badgeStore.clear()
            }
        }
    }

    private func setupBadgeHandlers() {
        socketManager.onChatBadgeUpdate = { roomId in
            badgeStore.onChatBadgeUpdate(roomId: roomId)
        }
        socketManager.onFriendBadgeUpdate = {
            badgeStore.onFriendBadgeUpdate()
        }
        socketManager.onBlogBadgeUpdate = { postId in
            badgeStore.onBlogBadgeUpdate(postId: postId)
        }
    }

    private func setupScheduledMessageHandlers() {
        socketManager.onScheduledMessageWarning = { warning in
            scheduledWarning = warning
        }
        socketManager.onScheduledMessageMissed = { missed in
            scheduledMissed = missed
        }
    }

    // MARK: - Scheduled Warning Overlay

    private func scheduledWarningOverlay(_ warning: ScheduledMessageWarning) -> some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .font(.title2)
                            .accessibilityHidden(true)
                        Text("Scheduled Message Reminder")
                            .font(.headline)
                    }

                    Text("Your message to **#\(warning.roomName)** sends in **\(warning.minutesRemaining) minute\(warning.minutesRemaining == 1 ? "" : "s")**.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)

                    Text(warning.messagePreview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .overlay(
                            Rectangle()
                                .fill(Color.orange.opacity(0.6))
                                .frame(width: 3),
                            alignment: .leading
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .lineLimit(4)

                    VStack(spacing: 8) {
                        Button {
                            Task { await confirmScheduledSend(warning.id) }
                        } label: {
                            Text("Send it")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        HStack(spacing: 8) {
                            Button {
                                Task { await cancelScheduledSend(warning.id) }
                            } label: {
                                Text("Don't send")
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)

                            Button {
                                Task { await editScheduledSend(warning.id) }
                            } label: {
                                Text("Edit first")
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(24)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 20)
                .padding(32)
            }
    }

    private func scheduledMissedOverlay(_ missed: ScheduledMessageMissed) -> some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                        Text("Scheduled Message Not Sent")
                            .font(.headline)
                    }

                    Text("Your scheduled message expired while you were editing it and was **not sent**.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)

                    Text(missed.messagePreview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .lineLimit(4)

                    Button {
                        scheduledMissed = nil
                    } label: {
                        Text("OK")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 20)
                .padding(32)
            }
    }

    // MARK: - Scheduled Message Actions

    private func confirmScheduledSend(_ id: Int) async {
        do {
            try await ChatAPIService.confirmScheduledMessage(id: id)
        } catch {
            // Silently fail
        }
        scheduledWarning = nil
    }

    private func cancelScheduledSend(_ id: Int) async {
        do {
            try await ChatAPIService.cancelScheduledMessage(id: id)
        } catch {
            // Silently fail
        }
        scheduledWarning = nil
    }

    private func editScheduledSend(_ id: Int) async {
        do {
            try await ChatAPIService.pauseScheduledMessage(id: id)
        } catch {
            // Silently fail
        }
        scheduledWarning = nil
        // User should navigate to scheduled messages view to edit
    }
}

struct MainTabView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(BadgeStore.self) private var badgeStore
    @State private var selectedTab = 0
    @State private var showBlogManagement = false
    @State private var showProfile = false
    @State private var showFriends = false
    @State private var showLegal = false
    @State private var showSettings = false
    @State private var showBilling = false

    // Account deletion
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var showDeleteAccountError = false

    // Shortcuts
    @State private var shortcuts: [Shortcut] = []
    @State private var selectedShortcut: Shortcut?
    @State private var showManageShortcuts = false

    // Admin / Impersonation
    @State private var hasAdminAccess = false
    @State private var showImpersonateSheet = false
    @State private var isImpersonating = false
    @State private var impersonatedHandle: String? = nil
    @State private var isStoppingImpersonation = false


    var body: some View {
        VStack(spacing: 0) {
            // Impersonation banner
            if isImpersonating, let handle = impersonatedHandle {
                impersonationBanner(handle: handle)
            }

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
                    .navigationDestination(isPresented: $showSettings) {
                        SettingsView()
                    }
                    .navigationDestination(isPresented: $showBilling) {
                        BillingView()
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
                                .accessibilityIdentifier("menuProfile")
                                Button("Chat", systemImage: "bubble.left.and.bubble.right") {
                                    selectedTab = 1
                                }
                                .accessibilityIdentifier("menuChat")
                                Button {
                                    showFriends = true
                                } label: {
                                    Label {
                                        HStack {
                                            Text("Friends")
                                            if badgeStore.friendRequestsUnread > 0 {
                                                Text("\(badgeStore.friendRequestsUnread)")
                                                    .font(.caption2.bold())
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(.red)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    } icon: {
                                        Image(systemName: "person.2")
                                    }
                                }
                                .accessibilityIdentifier("menuFriends")
                                Button {
                                    showBlogManagement = true
                                } label: {
                                    Label {
                                        HStack {
                                            Text("Blog")
                                            if badgeStore.blogCommentsUnread > 0 {
                                                Text("\(badgeStore.blogCommentsUnread)")
                                                    .font(.caption2.bold())
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(.red)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    } icon: {
                                        Image(systemName: "doc.richtext")
                                    }
                                }
                                .accessibilityIdentifier("menuBlog")
                                Button("Legal", systemImage: "doc.text") {
                                    showLegal = true
                                }
                                .accessibilityIdentifier("menuLegal")

                                if !shortcuts.isEmpty {
                                    Divider()
                                    Section("Shortcuts") {
                                        ForEach(shortcuts) { shortcut in
                                            Button {
                                                handleShortcut(shortcut)
                                            } label: {
                                                Label(shortcut.url == "/collections" ? "Artist Showcase" : shortcut.name, systemImage: shortcutIcon(for: shortcut.url))
                                            }
                                        }
                                        Button {
                                            showManageShortcuts = true
                                        } label: {
                                            Label("Manage Shortcuts", systemImage: "gear")
                                        }
                                    }
                                }

                                // Admin section (only shown for admins)
                                if hasAdminAccess {
                                    Divider()
                                    Section("Admin") {
                                        Button {
                                            showImpersonateSheet = true
                                        } label: {
                                            Label("Impersonate User", systemImage: "person.fill.viewfinder")
                                        }
                                        .accessibilityIdentifier("menuImpersonate")
                                    }
                                }

                                Divider()
                                Button("Billing & Plans", systemImage: "creditcard") {
                                    showBilling = true
                                }
                                .accessibilityIdentifier("menuBilling")
                                Button("Settings", systemImage: "gear") {
                                    showSettings = true
                                }
                                .accessibilityIdentifier("menuSettings")

                                Divider()
                                Button("Logout", systemImage: "rectangle.portrait.and.arrow.right") {
                                    Task { await authViewModel.logout() }
                                }
                                .accessibilityIdentifier("menuLogoutButton")
                                Button("Delete Account", systemImage: "trash", role: .destructive) {
                                    showDeleteAccountConfirmation = true
                                }
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "line.3.horizontal")
                                    if badgeStore.hasUnseenBadges || badgeStore.totalNonChat > 0 {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 8, height: 8)
                                            .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .accessibilityLabel(badgeStore.totalNonChat > 0 ? "Menu, \(badgeStore.totalNonChat) notifications" : "Menu")
                            .accessibilityIdentifier("menuButton")
                            .onTapGesture {
                                badgeStore.onMenuOpen()
                            }
                        }
                        ToolbarItem(placement: .principal) {
                            HStack(spacing: 6) {
                                Image("Logo")
                                    .accessibilityHidden(true)
                                Text("Breakroom")
                                    .font(.headline)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .task {
                        await loadShortcuts()
                    }
            }
            .tabItem { Label("Breakroom", systemImage: "square.grid.2x2") }
            .tag(0)
            .accessibilityIdentifier("tabBreakroom")

            NavigationStack {
                ChatListView()
            }
            .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
            .tag(1)
            .badge(badgeStore.totalChatUnread)
            .accessibilityIdentifier("tabChat")

            NavigationStack {
                EmploymentView()
            }
            .tabItem { Label("Jobs", systemImage: "briefcase") }
            .tag(2)
            .accessibilityIdentifier("tabJobs")

            NavigationStack {
                CompanyPortalView()
            }
            .tabItem { Label("Company", systemImage: "building.2") }
            .tag(3)
            .accessibilityIdentifier("tabCompany")

            NavigationStack {
                ToolShedView()
            }
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
        .sheet(isPresented: $showImpersonateSheet) {
            ImpersonateView(onImpersonated: {
                // Refresh impersonation state
                isImpersonating = KeychainManager.isImpersonating
                impersonatedHandle = KeychainManager.impersonatedHandle
            })
        }
        .task {
            await checkAdminAccess()
        }
        .onAppear {
            isImpersonating = KeychainManager.isImpersonating
            impersonatedHandle = KeychainManager.impersonatedHandle
        }
        .onChange(of: selectedTab) { _, newTab in
            // Track feature usage when switching tabs
            Task {
                switch newTab {
                case 1: await FeatureUsageTracker.shared.recordIfNeeded(AnalyticsFeature.chat.rawValue)
                case 3: await FeatureUsageTracker.shared.recordIfNeeded(AnalyticsFeature.companyPortal.rawValue)
                case 4: await FeatureUsageTracker.shared.recordIfNeeded(AnalyticsFeature.toolShed.rawValue)
                default: break
                }
            }
        }
        .onChange(of: showBlogManagement) { _, isShowing in
            if isShowing {
                Task { await FeatureUsageTracker.shared.recordIfNeeded(AnalyticsFeature.blog.rawValue) }
            }
        }
        .onChange(of: showFriends) { _, isShowing in
            if isShowing {
                Task { await FeatureUsageTracker.shared.recordIfNeeded(AnalyticsFeature.friends.rawValue) }
            }
        }
        } // Close VStack
    }

    // MARK: - Impersonation Banner

    private func impersonationBanner(handle: String) -> some View {
        HStack {
            Image(systemName: "person.fill.viewfinder")
                .accessibilityHidden(true)
            Text("Impersonating @\(handle)")
                .font(.subheadline.weight(.medium))
            Spacer()
            if isStoppingImpersonation {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            } else {
                Button("Stop") {
                    Task { await stopImpersonation() }
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.orange)
        .foregroundStyle(.white)
    }

    private func checkAdminAccess() async {
        do {
            hasAdminAccess = try await AdminAPIService.checkAdminAccess()
        } catch {
            hasAdminAccess = false
        }
    }

    private func stopImpersonation() async {
        isStoppingImpersonation = true
        do {
            try await AdminAPIService.stopImpersonation()
            isImpersonating = false
            impersonatedHandle = nil
            // Re-check admin access after returning to admin account
            await checkAdminAccess()
        } catch {
            // Show error?
        }
        isStoppingImpersonation = false
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
        case "/collections":
            CollectionsView()
        case "/blog":
            BlogManagementView()
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
