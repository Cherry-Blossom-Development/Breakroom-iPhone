import SwiftUI

struct InviteUsersView: View {
    let room: ChatRoom
    @Environment(\.dismiss) private var dismiss

    @State private var allUsers: [User] = []
    @State private var members: [ChatMember] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var invitingUserId: Int?

    private var nonMembers: [User] {
        let memberIds = Set(members.map(\.id))
        let users = allUsers.filter { !memberIds.contains($0.id) }
        guard !searchText.isEmpty else { return users }
        let query = searchText.lowercased()
        return users.filter {
            $0.handle.lowercased().contains(query) ||
            $0.displayName.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading users...")
                } else if nonMembers.isEmpty {
                    ContentUnavailableView(
                        "No Users to Invite",
                        systemImage: "person.slash",
                        description: Text("All users are already members of this room.")
                    )
                } else {
                    List(nonMembers) { user in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(user.handle)
                                    .font(.body)
                                if user.displayName != user.handle {
                                    Text(user.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityHidden(true)
                            Spacer()
                            Button {
                                Task { await inviteUser(user) }
                            } label: {
                                if invitingUserId == user.id {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Invite")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(invitingUserId != nil)
                            .accessibilityLabel(invitingUserId == user.id ? "Inviting \(user.displayName)" : "Invite \(user.displayName)")
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("\(user.displayName), @\(user.handle)")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search users")
            .navigationTitle("Invite to \(room.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        isLoading = true
        async let usersResult = ChatAPIService.getAllUsers()
        async let membersResult = ChatAPIService.getMembers(roomId: room.id)
        do {
            allUsers = try await usersResult
            members = try await membersResult
        } catch {
            // Best-effort load
        }
        isLoading = false
    }

    private func inviteUser(_ user: User) async {
        invitingUserId = user.id
        do {
            try await ChatAPIService.inviteUser(roomId: room.id, userId: user.id)
            // Add to members so they disappear from the invite list
            members.append(ChatMember(id: user.id, handle: user.handle, role: nil, joinedAt: nil))
            AccessibilityNotification.Announcement("Invitation sent to \(user.displayName)").post()
        } catch {
            AccessibilityNotification.Announcement("Failed to invite \(user.displayName)").post()
        }
        invitingUserId = nil
    }
}
