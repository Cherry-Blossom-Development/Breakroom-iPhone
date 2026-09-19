import SwiftUI

/// A small dot indicating online/offline status.
struct OnlineStatusDot: View {
    let userId: Int
    var showLabel: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isOnline ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 8, height: 8)

            if showLabel && isOnline {
                Text("Online now")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .accessibilityLabel(isOnline ? "Online" : "Offline")
    }

    private var isOnline: Bool {
        PresenceManager.shared.isOnline(userId)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            OnlineStatusDot(userId: 1)
            Text("User 1")
        }
        HStack {
            OnlineStatusDot(userId: 2, showLabel: true)
            Text("User 2")
        }
    }
    .padding()
}
