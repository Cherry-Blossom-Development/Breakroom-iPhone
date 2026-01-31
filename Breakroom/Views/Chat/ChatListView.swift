import SwiftUI

struct ChatListView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var chatViewModel = ChatViewModel()
    @State private var selectedRoom: ChatRoom?

    var body: some View {
        NavigationStack {
            Group {
                if chatViewModel.isLoadingRooms {
                    ProgressView("Loading rooms...")
                } else if chatViewModel.rooms.isEmpty {
                    ContentUnavailableView(
                        "No Chat Rooms",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Join or create a chat room to get started.")
                    )
                } else {
                    List(chatViewModel.rooms) { room in
                        NavigationLink(value: room) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(room.name)
                                    .font(.headline)
                                if let description = room.description, !description.isEmpty {
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Chat")
            .navigationDestination(for: ChatRoom.self) { room in
                ChatRoomView(room: room, chatViewModel: chatViewModel)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Logout") {
                        Task { await authViewModel.logout() }
                    }
                }
            }
            .task {
                await chatViewModel.loadRooms()
                chatViewModel.connectSocket()
            }
        }
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
