import SwiftUI

struct ChatRoomView: View {
    let room: ChatRoom
    @Bindable var chatViewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(chatViewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: chatViewModel.messages.count) {
                    if let lastMessage = chatViewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Message input
            HStack(spacing: 12) {
                TextField("Message", text: $chatViewModel.messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(.fill.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Button {
                    Task { await chatViewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(chatViewModel.messageText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .navigationTitle(room.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await chatViewModel.selectRoom(room)
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    private var isCurrentUser: Bool {
        guard let storedId = KeychainManager.get(.userId),
              let currentUserId = Int(storedId) else { return false }
        return message.userId == currentUserId
    }

    var body: some View {
        HStack {
            if isCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
                if !isCurrentUser, let handle = message.handle {
                    Text(handle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(message.message ?? "")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isCurrentUser ? Color.accentColor : Color(.systemGray5))
                    .foregroundStyle(isCurrentUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if !isCurrentUser { Spacer(minLength: 60) }
        }
    }
}
