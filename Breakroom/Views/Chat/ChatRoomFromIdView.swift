import SwiftUI

/// A wrapper view that loads a chat room by ID and presents ChatRoomView.
/// Used for navigation from widgets like Chat Summary.
struct ChatRoomFromIdView: View {
    let roomId: Int

    @State private var chatViewModel = ChatViewModel()
    @State private var room: ChatRoom?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading room...")
            } else if let error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await loadRoom() }
                    }
                    .buttonStyle(.bordered)
                }
            } else if let room {
                ChatRoomView(room: room, chatViewModel: chatViewModel)
            }
        }
        .task {
            await loadRoom()
        }
    }

    private func loadRoom() async {
        isLoading = true
        error = nil

        do {
            // Load all rooms and find the one we need
            let rooms = try await ChatAPIService.getRooms()
            if let foundRoom = rooms.first(where: { $0.id == roomId }) {
                room = foundRoom
                chatViewModel.socketManager = nil // Will be set by ChatRoomView's environment
            } else {
                error = "Room not found"
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
