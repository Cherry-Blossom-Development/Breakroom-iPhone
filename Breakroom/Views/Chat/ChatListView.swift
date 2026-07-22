import SwiftUI

// Navigation wrapper for DM rooms
struct DmNavigation: Hashable {
    let dm: ChatDm
    let partnerHandle: String

    init(_ dm: ChatDm) {
        self.dm = dm
        self.partnerHandle = dm.partnerHandle
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(dm.id)
    }

    static func == (lhs: DmNavigation, rhs: DmNavigation) -> Bool {
        lhs.dm.id == rhs.dm.id
    }
}

struct ChatListView: View {
    @Environment(ChatSocketManager.self) private var socketManager
    @Environment(BadgeStore.self) private var badgeStore
    @State private var chatViewModel = ChatViewModel()
    @State private var selectedRoom: ChatRoom?
    @State private var selectedDmNavigation: DmNavigation?
    @State private var showScheduledMessages = false

    var body: some View {
        ZStack {
            Color.clear // Ensures accessibility identifier anchor is always present

            if chatViewModel.isLoadingRooms {
                    ProgressView("Loading rooms...")
                } else if chatViewModel.rooms.isEmpty && chatViewModel.pendingInvites.isEmpty {
                    ContentUnavailableView(
                        "No Chat Rooms",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Join or create a chat room to get started.")
                    )
                } else {
                    List {
                        // Pending invites section
                        if !chatViewModel.pendingInvites.isEmpty {
                            Section("Pending Invites") {
                                ForEach(chatViewModel.pendingInvites) { invite in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("# \(invite.roomName)")
                                            .font(.headline)
                                            .accessibilityHidden(true)
                                        if let desc = invite.roomDescription, !desc.isEmpty {
                                            Text(desc)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                                .accessibilityHidden(true)
                                        }
                                        Text("Invited by \(invite.invitedByHandle)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .accessibilityHidden(true)
                                        HStack(spacing: 12) {
                                            Button("Accept") {
                                                Task { await chatViewModel.acceptInvite(invite) }
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.small)
                                            .accessibilityLabel("Accept invite to \(invite.roomName)")

                                            Button("Decline") {
                                                Task { await chatViewModel.declineInvite(invite) }
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            .accessibilityLabel("Decline invite to \(invite.roomName)")
                                        }
                                        .padding(.top, 2)
                                    }
                                    .padding(.vertical, 4)
                                    .accessibilityElement(children: .contain)
                                    .accessibilityLabel(inviteAccessibilityLabel(invite))
                                }
                            }
                        }

                        // Rooms section
                        Section {
                            ForEach(chatViewModel.rooms) { room in
                                HStack(spacing: 12) {
                                    // Kebab menu on the left
                                    Menu {
                                        if chatViewModel.isRoomOwner(room) {
                                            Button {
                                                chatViewModel.roomToEdit = room
                                                chatViewModel.showInviteUsers = true
                                            } label: {
                                                Label("Invite", systemImage: "person.badge.plus")
                                            }

                                            Button {
                                                chatViewModel.roomToEdit = room
                                                chatViewModel.showEditRoom = true
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }

                                            Button(role: .destructive) {
                                                chatViewModel.roomToDelete = room
                                                chatViewModel.showDeleteConfirmation = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }

                                        Button(role: .destructive) {
                                            chatViewModel.roomToLeave = room
                                            chatViewModel.showLeaveConfirmation = true
                                        } label: {
                                            Label("Leave", systemImage: "arrow.left.circle")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .rotationEffect(.degrees(90))
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 24, height: 24)
                                    }
                                    .accessibilityLabel("Room actions for \(room.name)")

                                    NavigationLink(value: room) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 4) {
                                                    Text("# \(room.name)")
                                                        .font(.headline)
                                                    if chatViewModel.isRoomOwner(room) {
                                                        Image(systemName: "crown.fill")
                                                            .font(.caption)
                                                            .foregroundStyle(.orange)
                                                            .accessibilityHidden(true)
                                                    }
                                                }
                                                if let description = room.description, !description.isEmpty {
                                                    Text(description)
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer()
                                            // Unread badge
                                            if let unread = badgeStore.chatUnread[room.id], unread > 0 {
                                                Text("\(unread)")
                                                    .font(.caption2.bold())
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(.red)
                                                    .clipShape(Capsule())
                                                    .accessibilityHidden(true)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .accessibilityIdentifier("roomItem")
                                    .accessibilityLabel(roomAccessibilityLabel(room))
                                }
                            }
                        }

                        // Direct Messages section
                        Section("Direct Messages") {
                            // Search field for finding users
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                                TextField("Find a user...", text: Binding(
                                    get: { chatViewModel.dmSearchQuery },
                                    set: { chatViewModel.updateDmSearchQuery($0) }
                                ))
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .accessibilityLabel("Search for user to message")

                                if !chatViewModel.dmSearchQuery.isEmpty {
                                    Button {
                                        chatViewModel.updateDmSearchQuery("")
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .accessibilityLabel("Clear search")
                                }
                            }
                            .padding(.vertical, 4)

                            // Search results
                            if !chatViewModel.dmSearchResults.isEmpty {
                                ForEach(chatViewModel.dmSearchResults) { user in
                                    Button {
                                        Task {
                                            if let roomInfo = await chatViewModel.startDm(with: user) {
                                                // Navigate to the DM
                                                let dm = ChatDm(
                                                    id: roomInfo.id,
                                                    partnerId: roomInfo.partnerId,
                                                    partnerHandle: roomInfo.partnerHandle,
                                                    unreadCount: 0,
                                                    lastMessage: nil,
                                                    lastMessageAt: nil
                                                )
                                                selectedDmNavigation = DmNavigation(dm)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            // Avatar circle with initial
                                            Circle()
                                                .fill(Color.accentColor.opacity(0.2))
                                                .frame(width: 36, height: 36)
                                                .overlay {
                                                    Text(String(user.handle.prefix(1)).uppercased())
                                                        .font(.headline)
                                                        .foregroundStyle(Color.accentColor)
                                                }
                                                .accessibilityHidden(true)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("@\(user.handle)")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(.primary)
                                                if user.displayName != user.handle {
                                                    Text(user.displayName)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }

                                            Spacer()

                                            if chatViewModel.isStartingDm {
                                                ProgressView()
                                                    .controlSize(.small)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .disabled(chatViewModel.isStartingDm)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("Start message with \(user.displayName), @\(user.handle)")
                                }
                            }

                            // Existing DM threads
                            ForEach(chatViewModel.dms) { dm in
                                NavigationLink(value: DmNavigation(dm)) {
                                    HStack(spacing: 12) {
                                        // Avatar circle with initial
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.2))
                                            .frame(width: 36, height: 36)
                                            .overlay {
                                                Text(String(dm.partnerHandle.prefix(1)).uppercased())
                                                    .font(.headline)
                                                    .foregroundStyle(Color.accentColor)
                                            }
                                            .accessibilityHidden(true)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("@\(dm.partnerHandle)")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            if let lastMessage = dm.lastMessage, !lastMessage.isEmpty {
                                                Text(lastMessage)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }

                                        Spacer()

                                        // Unread badge
                                        if dm.unreadCount > 0 {
                                            Text("\(dm.unreadCount)")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(.red)
                                                .clipShape(Capsule())
                                                .accessibilityHidden(true)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier("dmItem")
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(dmAccessibilityLabel(dm))
                            }
                        }
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenChat")
        .navigationTitle("Chat Rooms")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    connectionDot
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showScheduledMessages = true
                        } label: {
                            Image(systemName: "clock.badge")
                        }
                        .accessibilityLabel("Scheduled messages")

                        Button {
                            Task {
                                await chatViewModel.loadDiscoverableRooms()
                                chatViewModel.showAddRoom = true
                            }
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .accessibilityLabel("Join a room")

                        if chatViewModel.canCreateRoomPermission {
                            Button {
                                chatViewModel.showCreateRoom = true
                            } label: {
                                Image(systemName: "plus.bubble")
                            }
                            .accessibilityLabel("Create new room")
                        }
                    }
                }
            }
            .navigationDestination(for: ChatRoom.self) { room in
                ChatRoomView(room: room, chatViewModel: chatViewModel)
            }
            .navigationDestination(for: DmNavigation.self) { dmNav in
                DmRoomView(dm: dmNav.dm, chatViewModel: chatViewModel)
            }
            .navigationDestination(isPresented: $showScheduledMessages) {
                ScheduledMessagesView()
            }
            .sheet(isPresented: $chatViewModel.showCreateRoom) {
                CreateRoomView(chatViewModel: chatViewModel)
            }
            .sheet(isPresented: $chatViewModel.showEditRoom) {
                if let room = chatViewModel.roomToEdit {
                    EditRoomView(chatViewModel: chatViewModel, room: room)
                }
            }
            .sheet(isPresented: $chatViewModel.showInviteUsers) {
                if let room = chatViewModel.roomToEdit {
                    InviteUsersView(room: room)
                }
            }
            .confirmationDialog(
                "Delete Room",
                isPresented: $chatViewModel.showDeleteConfirmation,
                presenting: chatViewModel.roomToDelete
            ) { room in
                Button("Delete \"\(room.name)\"", role: .destructive) {
                    Task { await chatViewModel.deleteRoom(room) }
                }
            } message: { room in
                Text("Are you sure you want to delete \"\(room.name)\"? This cannot be undone.")
            }
            .confirmationDialog(
                "Leave Room",
                isPresented: $chatViewModel.showLeaveConfirmation,
                presenting: chatViewModel.roomToLeave
            ) { room in
                Button("Leave \"\(room.name)\"", role: .destructive) {
                    Task { await chatViewModel.leaveRoom(room) }
                }
            } message: { room in
                Text("Are you sure you want to leave \"\(room.name)\"?")
            }
            .sheet(isPresented: $chatViewModel.showAddRoom) {
                AddRoomSheet(chatViewModel: chatViewModel)
            }
            .alert("Error", isPresented: .init(
                get: { chatViewModel.errorMessage != nil },
                set: { if !$0 { chatViewModel.errorMessage = nil } }
            )) {
                Button("OK") { chatViewModel.errorMessage = nil }
            } message: {
                if let msg = chatViewModel.errorMessage {
                    Text(msg)
                }
            }
        .task {
            chatViewModel.socketManager = socketManager
            await chatViewModel.loadRooms()
            await chatViewModel.loadInvites()
            await chatViewModel.loadDms()
            await chatViewModel.loadAllUsersForDmSearch()
            await chatViewModel.checkPermissions()
            chatViewModel.connectSocket()
        }
    }

    private var connectionDot: some View {
        Circle()
            .fill(socketManager.connectionState == .connected ? .green : .red)
            .frame(width: 8, height: 8)
            .accessibilityLabel(socketManager.connectionState == .connected ? "Connected" : "Disconnected")
    }

    // MARK: - Accessibility Helpers

    private func inviteAccessibilityLabel(_ invite: ChatInvite) -> String {
        var parts: [String] = ["Invite to room \(invite.roomName)"]
        if let desc = invite.roomDescription, !desc.isEmpty {
            parts.append(desc)
        }
        parts.append("Invited by \(invite.invitedByHandle)")
        return parts.joined(separator: ". ")
    }

    private func roomAccessibilityLabel(_ room: ChatRoom) -> String {
        var parts: [String] = [room.name]
        if chatViewModel.isRoomOwner(room) {
            parts.append("You are the owner")
        }
        if let description = room.description, !description.isEmpty {
            parts.append(description)
        }
        if let unread = badgeStore.chatUnread[room.id], unread > 0 {
            parts.append("\(unread) unread message\(unread == 1 ? "" : "s")")
        }
        return parts.joined(separator: ". ")
    }

    private func dmAccessibilityLabel(_ dm: ChatDm) -> String {
        var parts: [String] = ["Direct message with @\(dm.partnerHandle)"]
        if let lastMessage = dm.lastMessage, !lastMessage.isEmpty {
            parts.append("Last message: \(lastMessage)")
        }
        if dm.unreadCount > 0 {
            parts.append("\(dm.unreadCount) unread message\(dm.unreadCount == 1 ? "" : "s")")
        }
        return parts.joined(separator: ". ")
    }
}

extension ChatRoom: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: ChatRoom, rhs: ChatRoom) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Add Room Sheet (for discoverable rooms)

struct AddRoomSheet: View {
    @Bindable var chatViewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if chatViewModel.discoverableRooms.isEmpty {
                    ContentUnavailableView(
                        "No Rooms Available",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("There are no discoverable rooms to join at this time.")
                    )
                } else {
                    List(chatViewModel.discoverableRooms) { room in
                        Button {
                            Task {
                                await chatViewModel.joinDiscoverableRoom(room)
                                dismiss()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("# \(room.name)")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                if let description = room.description, !description.isEmpty {
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(discoverableRoomLabel(room))
                        .accessibilityHint("Double tap to join")
                    }
                }
            }
            .navigationTitle("Add Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func discoverableRoomLabel(_ room: ChatRoom) -> String {
        var parts: [String] = [room.name]
        if let description = room.description, !description.isEmpty {
            parts.append(description)
        }
        return parts.joined(separator: ". ")
    }
}
