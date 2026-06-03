import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?

    // Notification settings
    @State private var notificationsEnabled = true
    @State private var notifyChatMessages = true
    @State private var notifyFriendRequests = true
    @State private var notifyBlogComments = true

    // Account deletion
    @State private var deletionConfirmed = false
    @State private var isDeletionSubmitting = false
    @State private var deletionSuccess = false
    @State private var deletionError: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading settings...")
            } else {
                settingsContent
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSettings()
        }
        .alert("Error", isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            if let error {
                Text(error)
            }
        }
    }

    private var settingsContent: some View {
        Form {
            notificationsSection
            accountDeletionSection
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section {
            Toggle("Allow notifications", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, _ in
                    Task { await saveSettings() }
                }

            if notificationsEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    notificationToggle(
                        title: "New messages in chat",
                        isOn: $notifyChatMessages
                    )

                    notificationToggle(
                        title: "Friend requests",
                        isOn: $notifyFriendRequests
                    )

                    notificationToggle(
                        title: "Comments on your content",
                        isOn: $notifyBlogComments
                    )
                }
                .padding(.leading, 16)
            }
        } header: {
            Text("Notifications")
        }
    }

    private func notificationToggle(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .disabled(!notificationsEnabled)
                .onChange(of: isOn.wrappedValue) { _, _ in
                    Task { await saveSettings() }
                }
        }
        .opacity(notificationsEnabled ? 1.0 : 0.4)
    }

    // MARK: - Account Deletion Section

    private var accountDeletionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text("Requesting deletion will permanently remove your account and all associated data. This action cannot be undone. An administrator will process your request.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if deletionSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Your deletion request has been submitted. An administrator will process it shortly.")
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    // Account field (read-only)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Account")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("@\(authViewModel.currentUsername ?? "user")")
                            .font(.body)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Confirmation checkbox
                    Button {
                        deletionConfirmed.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: deletionConfirmed ? "checkmark.square.fill" : "square")
                                .font(.title3)
                                .foregroundStyle(deletionConfirmed ? .red : .secondary)

                            Text("I understand this will permanently delete my account and all associated data")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)

                    if let deletionError {
                        Text(deletionError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    // Delete button
                    Button {
                        Task { await submitDeletionRequest() }
                    } label: {
                        HStack {
                            Spacer()
                            if isDeletionSubmitting {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Text("Request Account Deletion")
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(deletionConfirmed ? Color.red : Color.red.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(!deletionConfirmed || isDeletionSubmitting)
                }
            }
        } header: {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("Account Deletion")
            }
        }
    }

    // MARK: - Actions

    private func loadSettings() async {
        isLoading = true
        do {
            let settings = try await ProfileAPIService.getNotificationSettings()
            notificationsEnabled = settings.notificationsEnabled
            notifyChatMessages = settings.notifyChatMessages
            notifyFriendRequests = settings.notifyFriendRequests
            notifyBlogComments = settings.notifyBlogComments
        } catch {
            // Use defaults if settings don't exist yet
        }
        isLoading = false
    }

    private func saveSettings() async {
        let settings = NotificationSettings(
            notificationsEnabled: notificationsEnabled,
            notifyChatMessages: notifyChatMessages,
            notifyFriendRequests: notifyFriendRequests,
            notifyBlogComments: notifyBlogComments
        )

        do {
            try await ProfileAPIService.saveNotificationSettings(settings)
        } catch {
            self.error = "Failed to save settings"
        }
    }

    private func submitDeletionRequest() async {
        guard deletionConfirmed else { return }

        isDeletionSubmitting = true
        deletionError = nil

        do {
            try await ProfileAPIService.requestAccountDeletion()
            deletionSuccess = true
        } catch {
            deletionError = "Failed to submit deletion request. Please try again."
        }

        isDeletionSubmitting = false
    }
}
