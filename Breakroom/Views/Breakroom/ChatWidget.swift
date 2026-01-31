import SwiftUI

struct ChatWidget: View {
    let block: BreakroomBlock
    @State private var messages: [ChatMessage] = []
    @State private var messageText = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var error: String?

    private var roomId: Int? { block.contentId }

    var body: some View {
        if let roomId {
            chatContent(roomId: roomId)
        } else {
            noRoomView
        }
    }

    private func chatContent(roomId: Int) -> some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            messageInput(roomId: roomId)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .task {
            await loadMessages(roomId: roomId)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else if messages.isEmpty {
                    Text("No messages yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(messages) { message in
                            ChatWidgetMessageRow(message: message)
                                .id(message.id)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 300)
            .onChange(of: messages.count) {
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func messageInput(roomId: Int) -> some View {
        HStack(spacing: 8) {
            TextField("Message", text: $messageText)
                .textFieldStyle(.plain)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Button {
                Task { await sendMessage(roomId: roomId) }
            } label: {
                if isSending {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                }
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var noRoomView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No chat room assigned")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding()
    }

    // MARK: - Data

    private func loadMessages(roomId: Int) async {
        isLoading = true
        do {
            messages = try await ChatAPIService.getMessages(roomId: roomId, limit: 30)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func sendMessage(roomId: Int) async {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        isSending = true
        messageText = ""

        do {
            let sent = try await ChatAPIService.sendMessage(roomId: roomId, message: text)
            messages.append(sent)
        } catch {
            messageText = text
            self.error = error.localizedDescription
        }

        isSending = false
    }
}

// MARK: - Message Row (compact widget style, matching Android)

struct ChatWidgetMessageRow: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            headerRow
            messageContent
            Divider()
                .padding(.top, 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private var headerRow: some View {
        HStack {
            Text(message.handle ?? "Unknown")
                .font(.caption2)
                .fontWeight(.semibold)
            Spacer()
            Text(formattedTime)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        if let imagePath = message.imagePath, !imagePath.isEmpty {
            AsyncImage(url: imageURL(imagePath)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                default:
                    EmptyView()
                }
            }
            .padding(.top, 2)
        }

        if let text = message.message, !text.isEmpty {
            Text(text)
                .font(.caption)
                .padding(.top, 2)
        }
    }

    private func imageURL(_ path: String) -> URL? {
        URL(string: "\(APIClient.shared.baseURL)/uploads/\(path)")
    }

    private var formattedTime: String {
        guard let dateString = message.createdAt else { return "" }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else { return "" }
            return formatDate(date)
        }
        return formatDate(date)
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()

        if calendar.isDateInToday(date) {
            timeFormatter.dateFormat = "h:mm a"
        } else {
            timeFormatter.dateFormat = "M/d h:mm a"
        }

        return timeFormatter.string(from: date)
    }
}
