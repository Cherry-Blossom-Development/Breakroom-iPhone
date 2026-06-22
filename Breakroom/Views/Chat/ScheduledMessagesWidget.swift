import SwiftUI

/// A widget that displays scheduled messages in a compact list format.
/// Used to embed scheduled messages in other views (e.g., dashboard).
struct ScheduledMessagesWidget: View {
    @State private var messages: [ScheduledMessage]?
    @State private var error: String?

    /// Called when user taps "Create new Message" or wants to view full list
    var onNavigateToScheduledMessages: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            contentView
            Divider()
            footerButton
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            await loadMessages()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if messages == nil && error == nil {
            loadingView
        } else if let error {
            errorView(error)
        } else if let messages, messages.isEmpty {
            emptyView
        } else if let messages {
            listView(messages)
        }
    }

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .controlSize(.small)
            Spacer()
        }
        .frame(minHeight: 80)
    }

    private func errorView(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, minHeight: 80)
    }

    private var emptyView: some View {
        Text("No messages scheduled.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80)
    }

    private func listView(_ messages: [ScheduledMessage]) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(messages) { msg in
                    ScheduledMessageWidgetItem(message: msg)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 250)
    }

    // MARK: - Footer

    private var footerButton: some View {
        Button {
            onNavigateToScheduledMessages?()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.caption)
                Text("Create new Message")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .padding(.vertical, 12)
    }

    // MARK: - Data Loading

    private func loadMessages() async {
        do {
            messages = try await ChatAPIService.getScheduledMessages()
        } catch {
            self.error = "Failed to load"
        }
    }
}

// MARK: - Widget Item

private struct ScheduledMessageWidgetItem: View {
    let message: ScheduledMessage

    private var statusLabel: String {
        if message.isEditing {
            return "Editing paused"
        }
        switch message.status {
        case "warning_sent": return "Sending soon"
        case "confirmed": return "Confirmed"
        default: return "Scheduled"
        }
    }

    private var statusColor: Color {
        if message.isEditing {
            return .red
        }
        switch message.status {
        case "warning_sent": return .orange
        case "confirmed": return .green
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("#\(message.roomName ?? "Unknown")")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)

                Spacer()

                Text(statusLabel)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
            }

            Text(formatScheduledAt(message.scheduledAt))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(message.messageText)
                .font(.caption)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatScheduledAt(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString) else {
            return dateString
        }

        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "Today at \(timeString)"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow at \(timeString)"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            return "\(dateFormatter.string(from: date)) at \(timeString)"
        }
    }
}

#Preview {
    ScheduledMessagesWidget {
        print("Navigate to scheduled messages")
    }
    .padding()
}
