import SwiftUI

struct FriendsView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    enum Tab: String, CaseIterable {
        case friends = "Friends"
        case requests = "Requests"
        case sent = "Sent"
        case find = "Find"
        case blocked = "Blocked"
    }

    @State private var selectedTab: Tab = .friends
    @State private var friends: [Friend] = []
    @State private var requests: [FriendRequest] = []
    @State private var sent: [FriendRequest] = []
    @State private var blocked: [BlockedUser] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false

    // Find users
    @State private var allUsers: [User] = []
    @State private var searchText = ""
    @State private var sendingRequestTo: Int?

    // Confirmations
    @State private var friendToRemove: Friend?
    @State private var showRemoveConfirmation = false
    @State private var blockedToUnblock: BlockedUser?
    @State private var showUnblockConfirmation = false

    // In-progress action tracking
    @State private var processingUserId: Int?

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    if tab == .requests && !requests.isEmpty {
                        Text("\(tab.rawValue) (\(requests.count))").tag(tab)
                    } else {
                        Text(tab.rawValue).tag(tab)
                    }
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Content
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxHeight: .infinity)
                } else {
                    switch selectedTab {
                    case .friends:
                        friendsTab
                    case .requests:
                        requestsTab
                    case .sent:
                        sentTab
                    case .find:
                        findUsersTab
                    case .blocked:
                        blockedTab
                    }
                }
            }
        }
        .navigationTitle("Friends")
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .confirmationDialog(
            "Remove Friend",
            isPresented: $showRemoveConfirmation,
            presenting: friendToRemove
        ) { friend in
            Button("Remove", role: .destructive) {
                Task { await removeFriend(friend) }
            }
        } message: { friend in
            Text("Remove \(friend.displayName) from your friends?")
        }
        .confirmationDialog(
            "Unblock User",
            isPresented: $showUnblockConfirmation,
            presenting: blockedToUnblock
        ) { user in
            Button("Unblock") {
                Task { await unblockUser(user) }
            }
        } message: { user in
            Text("Unblock \(user.displayName)?")
        }
        .refreshable {
            await loadAll()
        }
        .task {
            await loadAll()
        }
    }

    // MARK: - Friends Tab

    private var friendsTab: some View {
        Group {
            if friends.isEmpty {
                ContentUnavailableView(
                    "No Friends Yet",
                    systemImage: "person.2",
                    description: Text("Use the Find tab to search for people.")
                )
            } else {
                List(friends) { friend in
                    friendRow(friend)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                friendToRemove = friend
                                showRemoveConfirmation = true
                            } label: {
                                Label("Remove", systemImage: "person.badge.minus")
                            }
                        }
                }
                .listStyle(.plain)
            }
        }
    }

    private func friendRow(_ friend: Friend) -> some View {
        HStack(spacing: 12) {
            userAvatar(url: friend.photoURL, name: friend.displayName, handle: friend.handle)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.body.weight(.medium))
                Text("@\(friend.handle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Requests Tab

    private var requestsTab: some View {
        Group {
            if requests.isEmpty {
                ContentUnavailableView(
                    "No Pending Requests",
                    systemImage: "person.badge.clock",
                    description: Text("Friend requests you receive will appear here.")
                )
            } else {
                List(requests) { request in
                    requestRow(request)
                }
                .listStyle(.plain)
            }
        }
    }

    private func requestRow(_ request: FriendRequest) -> some View {
        HStack(spacing: 12) {
            userAvatar(url: request.photoURL, name: request.displayName, handle: request.handle)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.displayName)
                    .font(.body.weight(.medium))
                Text("@\(request.handle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if processingUserId == request.id {
                ProgressView()
                    .controlSize(.small)
            } else {
                HStack(spacing: 8) {
                    Button {
                        Task { await acceptRequest(request) }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button(role: .destructive) {
                        Task { await declineRequest(request) }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Sent Tab

    private var sentTab: some View {
        Group {
            if sent.isEmpty {
                ContentUnavailableView(
                    "No Sent Requests",
                    systemImage: "paperplane",
                    description: Text("Friend requests you send will appear here.")
                )
            } else {
                List(sent) { request in
                    sentRow(request)
                }
                .listStyle(.plain)
            }
        }
    }

    private func sentRow(_ request: FriendRequest) -> some View {
        HStack(spacing: 12) {
            userAvatar(url: request.photoURL, name: request.displayName, handle: request.handle)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.displayName)
                    .font(.body.weight(.medium))
                Text("@\(request.handle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if processingUserId == request.id {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Cancel", role: .destructive) {
                    Task { await cancelRequest(request) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Find Users Tab

    private var filteredUsers: [User] {
        let currentUserId = authViewModel.currentUserId ?? -1
        let friendIds = Set(friends.map(\.id))
        let requestIds = Set(requests.map(\.id))
        let sentIds = Set(sent.map(\.id))
        let blockedIds = Set(blocked.map(\.id))
        let excluded = friendIds.union(requestIds).union(sentIds).union(blockedIds).union([currentUserId])

        let available = allUsers.filter { !excluded.contains($0.id) }

        guard !searchText.isEmpty else { return available }
        let query = searchText.lowercased()
        return available.filter {
            $0.handle.lowercased().contains(query) ||
            $0.displayName.lowercased().contains(query) ||
            ($0.email?.lowercased().contains(query) ?? false)
        }
    }

    private var findUsersTab: some View {
        Group {
            if allUsers.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Users Found",
                    systemImage: "magnifyingglass",
                    description: Text("Could not load users.")
                )
            } else if filteredUsers.isEmpty && !searchText.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No users match \"\(searchText)\".")
                )
            } else if filteredUsers.isEmpty {
                ContentUnavailableView(
                    "No Users to Add",
                    systemImage: "person.badge.plus",
                    description: Text("Everyone is already your friend!")
                )
            } else {
                List(filteredUsers) { user in
                    findUserRow(user)
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $searchText, prompt: "Search by name or handle")
    }

    private func findUserRow(_ user: User) -> some View {
        HStack(spacing: 12) {
            userAvatar(photoPath: user.profilePhotoPath, name: user.displayName, handle: user.handle)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.body.weight(.medium))
                Text("@\(user.handle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if sendingRequestTo == user.id {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Add") {
                    Task { await sendRequest(user) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(sendingRequestTo != nil)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Blocked Tab

    private var blockedTab: some View {
        Group {
            if blocked.isEmpty {
                ContentUnavailableView(
                    "No Blocked Users",
                    systemImage: "hand.raised.slash",
                    description: Text("Users you block will appear here.")
                )
            } else {
                List(blocked) { user in
                    blockedRow(user)
                }
                .listStyle(.plain)
            }
        }
    }

    private func blockedRow(_ user: BlockedUser) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(user.handle.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.body.weight(.medium))
                Text("@\(user.handle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if processingUserId == user.id {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Unblock") {
                    blockedToUnblock = user
                    showUnblockConfirmation = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Avatar Helper

    private func userAvatar(url: URL? = nil, photoPath: String? = nil, name: String, handle: String) -> some View {
        let resolvedURL: URL? = url ?? {
            guard let photoPath, !photoPath.isEmpty else { return nil }
            return URL(string: "\(APIClient.shared.baseURL)/api/uploads/\(photoPath)")
        }()

        return Group {
            if let resolvedURL {
                AsyncImage(url: resolvedURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsCircle(name: name, handle: handle)
                }
            } else {
                initialsCircle(name: name, handle: handle)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }

    private func initialsCircle(name: String, handle: String) -> some View {
        Circle()
            .fill(Color.accentColor.opacity(0.2))
            .overlay {
                Text((name.first ?? handle.first ?? Character("?")).uppercased())
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
            }
    }

    // MARK: - Data Loading

    private func loadAll() async {
        async let f = FriendsAPIService.getFriends()
        async let r = FriendsAPIService.getRequests()
        async let s = FriendsAPIService.getSentRequests()
        async let b = FriendsAPIService.getBlocked()
        async let u = ChatAPIService.getAllUsers()

        do {
            friends = try await f
            requests = try await r
            sent = try await s
            blocked = try await b
            allUsers = try await u
        } catch {
            errorMessage = error.localizedDescription
            if isLoading { showError = true }
        }
        isLoading = false
    }

    // MARK: - Actions

    private func sendRequest(_ user: User) async {
        sendingRequestTo = user.id
        do {
            try await FriendsAPIService.sendRequest(userId: user.id)
            // Move to sent list
            sent.append(FriendRequest(
                id: user.id,
                handle: user.handle,
                firstName: user.firstName,
                lastName: user.lastName,
                photoPath: user.profilePhotoPath,
                requestedAt: nil
            ))
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        sendingRequestTo = nil
    }

    private func acceptRequest(_ request: FriendRequest) async {
        processingUserId = request.id
        do {
            try await FriendsAPIService.acceptRequest(userId: request.id)
            requests.removeAll { $0.id == request.id }
            friends.append(Friend(
                id: request.id,
                handle: request.handle,
                firstName: request.firstName,
                lastName: request.lastName,
                photoPath: request.photoPath,
                friendsSince: nil
            ))
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        processingUserId = nil
    }

    private func declineRequest(_ request: FriendRequest) async {
        processingUserId = request.id
        do {
            try await FriendsAPIService.declineRequest(userId: request.id)
            requests.removeAll { $0.id == request.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        processingUserId = nil
    }

    private func cancelRequest(_ request: FriendRequest) async {
        processingUserId = request.id
        do {
            try await FriendsAPIService.cancelRequest(userId: request.id)
            sent.removeAll { $0.id == request.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        processingUserId = nil
    }

    private func removeFriend(_ friend: Friend) async {
        let index = friends.firstIndex(where: { $0.id == friend.id })
        if let index { friends.remove(at: index) }

        do {
            try await FriendsAPIService.removeFriend(userId: friend.id)
        } catch {
            // Restore on failure
            if let index {
                friends.insert(friend, at: min(index, friends.count))
            }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func unblockUser(_ user: BlockedUser) async {
        processingUserId = user.id
        do {
            try await FriendsAPIService.unblockUser(userId: user.id)
            blocked.removeAll { $0.id == user.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        processingUserId = nil
    }
}
