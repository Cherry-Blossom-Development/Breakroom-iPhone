import SwiftUI

struct ChatListView: View {
    @Environment(ChatSocketManager.self) private var socketManager
    @State private var chatViewModel = ChatViewModel()
    @State private var selectedRoom: ChatRoom?

    var body: some View {
        NavigationStack {
            Group {
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
                                        if let desc = invite.roomDescription, !desc.isEmpty {
                                            Text(desc)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Text("Invited by \(invite.invitedByHandle)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        HStack(spacing: 12) {
                                            Button("Accept") {
                                                Task { await chatViewModel.acceptInvite(invite) }
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.small)

                                            Button("Decline") {
                                                Task { await chatViewModel.declineInvite(invite) }
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        }
                                        .padding(.top, 2)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        // Rooms section
                        Section("Rooms") {
                            ForEach(chatViewModel.rooms) { room in
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
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier("roomItem")
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    // Leave action for all rooms
                                    Button {
                                        chatViewModel.roomToLeave = room
                                        chatViewModel.showLeaveConfirmation = true
                                    } label: {
                                        Label("Leave", systemImage: "arrow.left.circle")
                                    }
                                    .tint(.yellow)

                                    if chatViewModel.isRoomOwner(room) {
                                        Button(role: .destructive) {
                                            chatViewModel.roomToDelete = room
                                            chatViewModel.showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }

                                        Button {
                                            chatViewModel.roomToEdit = room
                                            chatViewModel.showEditRoom = true
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.orange)
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    if chatViewModel.isRoomOwner(room) {
                                        Button {
                                            chatViewModel.roomToEdit = room
                                            chatViewModel.showInviteUsers = true
                                        } label: {
                                            Label("Invite", systemImage: "person.badge.plus")
                                        }
                                        .tint(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    connectionDot
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            Task {
                                await chatViewModel.loadDiscoverableRooms()
                                chatViewModel.showAddRoom = true
                            }
                        } label: {
                            Image(systemName: "plus.circle")
                        }

                        if chatViewModel.canCreateRoomPermission {
                            Button {
                                chatViewModel.showCreateRoom = true
                            } label: {
                                Image(systemName: "plus.bubble")
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: ChatRoom.self) { room in
                ChatRoomView(room: room, chatViewModel: chatViewModel)
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
                await chatViewModel.checkPermissions()
                chatViewModel.connectSocket()
            }
        }
    }

    private var connectionDot: some View {
        Circle()
            .fill(socketManager.connectionState == .connected ? .green : .red)
            .frame(width: 8, height: 8)
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
}
