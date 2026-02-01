import SwiftUI

struct CreateRoomView: View {
    @Bindable var chatViewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var searchText = ""
    @State private var allUsers: [User] = []
    @State private var selectedUserIds: Set<Int> = []
    @State private var isLoading = false

    private var filteredUsers: [User] {
        guard !searchText.isEmpty else { return allUsers }
        let query = searchText.lowercased()
        return allUsers.filter {
            $0.handle.lowercased().contains(query) ||
            $0.displayName.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Room Details") {
                    TextField("Room Name", text: $name)
                    TextField("Description (optional)", text: $description)
                }

                if !selectedUserIds.isEmpty {
                    Section("Selected Users") {
                        let selected = allUsers.filter { selectedUserIds.contains($0.id) }
                        FlowLayout(spacing: 8) {
                            ForEach(selected, id: \.id) { user in
                                HStack(spacing: 4) {
                                    Text(user.displayName)
                                        .font(.caption)
                                    Button {
                                        selectedUserIds.remove(user.id)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.fill.tertiary)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }

                Section("Invite Users") {
                    TextField("Search users...", text: $searchText)

                    if isLoading {
                        ProgressView()
                    } else {
                        ForEach(filteredUsers, id: \.id) { user in
                            UserRow(user: user, isSelected: selectedUserIds.contains(user.id)) {
                                toggleUser(user.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await chatViewModel.createRoom(
                                name: name,
                                description: description.isEmpty ? nil : description,
                                inviteUserIds: Array(selectedUserIds)
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task {
                await loadUsers()
            }
        }
    }

    private func toggleUser(_ id: Int) {
        if selectedUserIds.contains(id) {
            selectedUserIds.remove(id)
        } else {
            selectedUserIds.insert(id)
        }
    }

    private func loadUsers() async {
        isLoading = true
        do {
            let users = try await ChatAPIService.getAllUsers()
            let currentId = chatViewModel.currentUserId
            allUsers = users.filter { $0.id != currentId }
        } catch {
            // Silently fail; user can still create room without invites
        }
        isLoading = false
    }
}

private struct UserRow: View {
    let user: User
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}

// Simple flow layout for user tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxWidth = max(maxWidth, x)
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
