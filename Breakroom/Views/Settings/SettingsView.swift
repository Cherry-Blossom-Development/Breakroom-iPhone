import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?

    // Notification settings
    @State private var notificationsEnabled = true
    @State private var notifyChatMessages = true
    @State private var notifyFriendRequests = true
    @State private var notifyBlogComments = true

    // Alternate email
    @State private var alternateEmail: String?
    @State private var alternateEmailVerified = false
    @State private var sendNoticesToAlternateEmail = false
    @State private var alternateEmailInput = ""
    @State private var isEditingAlternateEmail = false
    @State private var isAlternateEmailSaving = false
    @State private var alternateEmailError: String?

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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await loadAlternateEmail() }
            }
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
            alternateEmailSection
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
                .accessibilityHidden(true)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .disabled(!notificationsEnabled)
                .onChange(of: isOn.wrappedValue) { _, _ in
                    Task { await saveSettings() }
                }
                .accessibilityLabel(title)
        }
        .opacity(notificationsEnabled ? 1.0 : 0.4)
    }

    // MARK: - Alternate Email Section

    private var alternateEmailSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Add a secondary email address to receive important account notices (band invites, seller notifications, etc.).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let email = alternateEmail, !isEditingAlternateEmail {
                    // Has an alternate email set
                    alternateEmailDisplay(email: email)
                } else {
                    // No email set or editing
                    alternateEmailForm
                }

                if let alternateEmailError {
                    Text(alternateEmailError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("Alternate Email")
        }
    }

    private func alternateEmailDisplay(email: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(email)
                        .font(.body)

                    if alternateEmailVerified {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Verified")
                                .foregroundStyle(.green)
                        }
                        .font(.caption)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundStyle(.orange)
                            Text("Pending verification — check your inbox")
                                .foregroundStyle(.orange)
                        }
                        .font(.caption)
                    }
                }
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if alternateEmailVerified {
                // Verified: show toggle for sending notices
                notificationToggle(
                    title: "Also send notices to this address",
                    isOn: Binding(
                        get: { sendNoticesToAlternateEmail },
                        set: { newValue in
                            Task { await toggleAlternateEmailNotify(newValue) }
                        }
                    )
                )
            } else {
                // Unverified: show resend button
                Button {
                    Task { await resendVerification() }
                } label: {
                    HStack {
                        if isAlternateEmailSaving {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Resend Verification Email")
                    }
                }
                .disabled(isAlternateEmailSaving)
            }

            // Change / Remove buttons
            HStack(spacing: 12) {
                Button("Change") {
                    alternateEmailInput = email
                    isEditingAlternateEmail = true
                }
                .font(.subheadline)

                Button("Remove", role: .destructive) {
                    Task { await removeAlternateEmail() }
                }
                .font(.subheadline)
            }
        }
    }

    private var alternateEmailForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Email address", text: $alternateEmailInput)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            HStack {
                Button {
                    Task { await saveAlternateEmail() }
                } label: {
                    HStack {
                        if isAlternateEmailSaving {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Send Verification Email")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(alternateEmailInput.trimmingCharacters(in: .whitespaces).isEmpty || isAlternateEmailSaving)

                if isEditingAlternateEmail {
                    Button("Cancel") {
                        isEditingAlternateEmail = false
                        alternateEmailInput = ""
                        alternateEmailError = nil
                    }
                }
            }
        }
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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Confirm account deletion")
                    .accessibilityValue(deletionConfirmed ? "Confirmed" : "Not confirmed")
                    .accessibilityHint("I understand this will permanently delete my account and all associated data")

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

        async let notificationTask: () = loadNotificationSettings()
        async let alternateEmailTask: () = loadAlternateEmail()

        _ = await (notificationTask, alternateEmailTask)

        isLoading = false
    }

    private func loadNotificationSettings() async {
        do {
            let settings = try await ProfileAPIService.getNotificationSettings()
            notificationsEnabled = settings.notificationsEnabled
            notifyChatMessages = settings.notifyChatMessages
            notifyFriendRequests = settings.notifyFriendRequests
            notifyBlogComments = settings.notifyBlogComments
        } catch {
            // Use defaults if settings don't exist yet
        }
    }

    private func loadAlternateEmail() async {
        do {
            let response = try await ProfileAPIService.getAlternateEmail()
            alternateEmail = response.alternateEmail
            alternateEmailVerified = response.alternateEmailVerified
            sendNoticesToAlternateEmail = response.sendNoticesToAlternateEmail
            isEditingAlternateEmail = false
        } catch {
            // Non-critical, just won't show alternate email
        }
    }

    private func saveAlternateEmail() async {
        let email = alternateEmailInput.trimmingCharacters(in: .whitespaces)
        guard !email.isEmpty else { return }

        isAlternateEmailSaving = true
        alternateEmailError = nil

        do {
            try await ProfileAPIService.setAlternateEmail(email)
            alternateEmail = email
            alternateEmailVerified = false
            sendNoticesToAlternateEmail = false
            isEditingAlternateEmail = false
            alternateEmailInput = ""
        } catch let error as APIError {
            switch error {
            case .serverError(let message):
                if message.contains("409") || message.lowercased().contains("already") {
                    alternateEmailError = "This email is already in use by another account."
                } else if message.contains("400") || message.lowercased().contains("invalid") {
                    alternateEmailError = "Please enter a valid email address."
                } else {
                    alternateEmailError = "Failed to set alternate email."
                }
            default:
                alternateEmailError = "Failed to set alternate email."
            }
        } catch {
            alternateEmailError = "Failed to set alternate email."
        }

        isAlternateEmailSaving = false
    }

    private func resendVerification() async {
        isAlternateEmailSaving = true
        alternateEmailError = nil

        do {
            try await ProfileAPIService.resendAlternateEmailVerification()
            alternateEmailError = nil
        } catch {
            alternateEmailError = "Failed to resend verification email."
        }

        isAlternateEmailSaving = false
    }

    private func removeAlternateEmail() async {
        isAlternateEmailSaving = true
        alternateEmailError = nil

        do {
            try await ProfileAPIService.setAlternateEmail("")
            alternateEmail = nil
            alternateEmailVerified = false
            sendNoticesToAlternateEmail = false
            alternateEmailInput = ""
        } catch {
            alternateEmailError = "Failed to remove alternate email."
        }

        isAlternateEmailSaving = false
    }

    private func toggleAlternateEmailNotify(_ enabled: Bool) async {
        let previousValue = sendNoticesToAlternateEmail
        sendNoticesToAlternateEmail = enabled

        do {
            try await ProfileAPIService.setAlternateEmailNotify(enabled)
        } catch {
            sendNoticesToAlternateEmail = previousValue
            alternateEmailError = "Failed to update notification preference."
        }
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
