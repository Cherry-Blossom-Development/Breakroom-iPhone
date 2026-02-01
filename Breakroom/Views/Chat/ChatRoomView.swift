import SwiftUI
import PhotosUI
import AVKit

struct ChatRoomView: View {
    let room: ChatRoom
    @Bindable var chatViewModel: ChatViewModel
    @Environment(ChatSocketManager.self) private var socketManager

    @State private var selectedPhoto: PhotosPickerItem?

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

            if !chatViewModel.typingUsers.isEmpty {
                HStack {
                    Text(chatViewModel.typingUsers.joined(separator: ", ")
                         + (chatViewModel.typingUsers.count == 1 ? " is" : " are")
                         + " typing...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .italic()
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 2)
            }

            Divider()

            // Upload progress
            if chatViewModel.isUploadingMedia {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Uploading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            // Message input
            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhoto, matching: .any(of: [.images, .videos])) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .disabled(chatViewModel.isUploadingMedia)

                TextField("Message", text: $chatViewModel.messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(.fill.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .onChange(of: chatViewModel.messageText) {
                        chatViewModel.handleTypingChanged()
                    }

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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(socketManager.connectionState == .connected ? .green : .red)
                        .frame(width: 8, height: 8)
                    VStack(spacing: 0) {
                        Text("# \(room.name)")
                            .font(.headline)
                            .lineLimit(1)
                        if let desc = room.description, !desc.isEmpty {
                            Text(desc)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .onChange(of: selectedPhoto) {
            guard let item = selectedPhoto else { return }
            selectedPhoto = nil
            Task { await handlePickedMedia(item) }
        }
        .task {
            await chatViewModel.selectRoom(room)
        }
    }

    private func handlePickedMedia(_ item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self) {
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                await chatViewModel.uploadVideo(data: data, filename: "video.mp4")
            } else {
                await chatViewModel.uploadImage(data: data, filename: "image.jpg")
            }
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

    private static let baseURL = "https://www.prosaurus.com"

    var body: some View {
        HStack {
            if isCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
                if !isCurrentUser, let handle = message.handle {
                    Text(handle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Image attachment
                if let imagePath = message.imagePath, !imagePath.isEmpty {
                    AsyncImage(url: URL(string: "\(Self.baseURL)/api/uploads/\(imagePath)")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 240, maxHeight: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure:
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                                .frame(width: 100, height: 100)
                        default:
                            ProgressView()
                                .frame(width: 100, height: 100)
                        }
                    }
                }

                // Video attachment
                if let videoPath = message.videoPath, !videoPath.isEmpty {
                    if let url = URL(string: "\(Self.baseURL)/api/uploads/\(videoPath)") {
                        VideoPlayer(player: AVPlayer(url: url))
                            .frame(width: 240, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // Text message
                if let text = message.message, !text.isEmpty {
                    Text(text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isCurrentUser ? Color.accentColor : Color(.systemGray5))
                        .foregroundStyle(isCurrentUser ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            if !isCurrentUser { Spacer(minLength: 60) }
        }
    }
}
