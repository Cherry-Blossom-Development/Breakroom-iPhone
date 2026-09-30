import SwiftUI

/// Project settings view for managing sprint duration, members, roles, and invites.
/// Mirrors Android's ProjectSettingsScreen and web's ProjectSettingsPage.vue.
struct ProjectSettingsView: View {
    let projectId: Int

    @Environment(\.dismiss) private var dismiss

    // Data state
    @State private var settings: ProjectSettings?
    @State private var members: [ProjectMember] = []
    @State private var sprintDurations: [Int] = [7, 14, 21, 28]
    @State private var roles: [String] = ProjectRoles.all
    @State private var currentUserId: Int?
    @State private var canManage = false
    @State private var canManageOwners = false

    // UI state
    @State private var isLoading = true
    @State private var error: String?

    // Sprint editing
    @State private var selectedSprintDays: Int?
    @State private var isSavingSettings = false
    @State private var settingsMessage: String?
    @State private var settingsError: String?

    // Member management
    @State private var busyMemberId: Int?
    @State private var memberError: String?
    @State private var confirmRemoveMember: ProjectMember?

    // Invite form
    @State private var inviteIdentifier = ""
    @State private var inviteRole = "member"
    @State private var isInviting = false
    @State private var inviteMessage: String?
    @State private var inviteError: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading settings...")
            } else if let error = error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await loadSettings() }
                    }
                }
            } else {
                settingsContent
            }
        }
        .task {
            await loadSettings()
        }
        .alert("Confirm Removal", isPresented: .init(
            get: { confirmRemoveMember != nil },
            set: { if !$0 { confirmRemoveMember = nil } }
        )) {
            Button("Cancel", role: .cancel) { }
            Button(removeButtonLabel(confirmRemoveMember), role: .destructive) {
                if let member = confirmRemoveMember {
                    Task { await removeMember(member) }
                }
            }
        } message: {
            Text(removeConfirmMessage(confirmRemoveMember))
        }
    }

    // MARK: - Settings Content

    private var settingsContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                sprintCard
                membersCard
            }
            .padding()
        }
    }

    // MARK: - Sprint Card

    private var sprintCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sprints")
                .font(.headline)

            Text("Sprint duration")
                .font(.subheadline)

            HStack {
                Picker("Sprint duration", selection: Binding(
                    get: { selectedSprintDays ?? settings?.sprintDurationDays ?? 14 },
                    set: { selectedSprintDays = $0 }
                )) {
                    ForEach(sprintDurations, id: \.self) { days in
                        Text(weeksLabel(days)).tag(days)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!canManage || isSavingSettings)

                if canManage {
                    Button {
                        Task { await saveSettings() }
                    } label: {
                        if isSavingSettings {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Save")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSavingSettings || selectedSprintDays == nil || selectedSprintDays == settings?.sprintDurationDays)
                }
            }

            if let message = settingsMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            if let error = settingsError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !canManage {
                Text("Only project owners and managers can change settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Members Card

    private var membersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Members")
                .font(.headline)

            Text("Company employees can always open this project. Membership gives people outside the company access and decides who manages the project.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error = memberError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if members.isEmpty {
                Text("No members yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(members) { member in
                    memberRow(member)
                    Divider()
                }
            }

            if canManage {
                inviteForm
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Member Row

    private func memberRow(_ member: ProjectMember) -> some View {
        let isBusy = busyMemberId == member.userId
        let isSelf = member.userId == currentUserId

        return VStack(alignment: .leading, spacing: 8) {
            // Name and badges
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(member.displayName)
                            .font(.body.weight(.medium))
                        if isSelf {
                            Text("(you)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let handle = member.handle {
                        Text("@\(handle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if member.isInvited {
                    badge("Invite pending", color: .orange)
                }
                if member.isEmployee {
                    badge("Employee", color: .purple)
                }
            }

            // Role and actions
            HStack {
                if canEditMember(member) {
                    Picker("Role", selection: Binding(
                        get: { member.role },
                        set: { newRole in Task { await changeRole(member, to: newRole) } }
                    )) {
                        ForEach(assignableRoles(for: member), id: \.self) { role in
                            Text(roleLabel(role)).tag(role)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(isBusy)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(roleLabel(member.role))
                            .font(.subheadline)
                        Text(roleHint(member.role))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if canRemoveMember(member) {
                    Button(removeButtonLabel(member), role: .destructive) {
                        confirmRemoveMember = member
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isBusy)
                }
            }
        }
    }

    // MARK: - Invite Form

    private var inviteForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Invite someone")
                .font(.subheadline.weight(.semibold))

            TextField("Handle or email", text: $inviteIdentifier)
                .textFieldStyle(.roundedBorder)
                .disabled(isInviting)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            HStack {
                Picker("Role", selection: $inviteRole) {
                    ForEach(assignableRolesForInvite, id: \.self) { role in
                        Text(roleLabel(role)).tag(role)
                    }
                }
                .pickerStyle(.menu)
                .disabled(isInviting)

                Button {
                    Task { await sendInvite() }
                } label: {
                    if isInviting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Send Invite")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isInviting || inviteIdentifier.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Text("\(roleLabel(inviteRole)): \(roleHint(inviteRole)). They'll get an email and can accept from their Projects page.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let message = inviteMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            if let error = inviteError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Helpers

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func weeksLabel(_ days: Int) -> String {
        let weeks = days / 7
        return "\(weeks) week\(weeks == 1 ? "" : "s")"
    }

    private func roleLabel(_ role: String) -> String {
        switch role {
        case "owner": return "Owner"
        case "manager": return "Manager"
        case "member": return "Member"
        case "viewer": return "Viewer"
        default: return role.capitalized
        }
    }

    private func roleHint(_ role: String) -> String {
        switch role {
        case "owner": return "Can manage settings and members"
        case "manager": return "Can manage members"
        case "member": return "Can work on tickets"
        case "viewer": return "Read-only access"
        default: return ""
        }
    }

    private func canEditMember(_ member: ProjectMember) -> Bool {
        guard canManage else { return false }
        if member.role == "owner" && !canManageOwners { return false }
        return true
    }

    private func canRemoveMember(_ member: ProjectMember) -> Bool {
        // Can always leave
        if member.userId == currentUserId { return true }
        // Otherwise need manage permission
        guard canManage else { return false }
        if member.role == "owner" && !canManageOwners { return false }
        return true
    }

    private func assignableRoles(for member: ProjectMember) -> [String] {
        var result = canManageOwners ? roles : roles.filter { $0 != "owner" }
        // Keep current role even if not assignable
        if !result.contains(member.role) {
            result.append(member.role)
        }
        return result
    }

    private var assignableRolesForInvite: [String] {
        canManageOwners ? roles : roles.filter { $0 != "owner" }
    }

    private func removeButtonLabel(_ member: ProjectMember?) -> String {
        guard let member = member else { return "Remove" }
        if member.isInvited { return "Cancel" }
        if member.userId == currentUserId { return "Leave" }
        return "Remove"
    }

    private func removeConfirmMessage(_ member: ProjectMember?) -> String {
        guard let member = member else { return "" }
        if member.isInvited { return "Cancel the invite for \(member.displayName)?" }
        if member.userId == currentUserId { return "Leave this project?" }
        return "Remove \(member.displayName) from this project?"
    }

    // MARK: - API Calls

    private func loadSettings() async {
        isLoading = true
        error = nil

        do {
            let response = try await ProjectAPIService.getSettings(projectId: projectId)
            settings = response.settings
            members = response.members
            if let durations = response.sprintDurations {
                sprintDurations = durations
            }
            if let r = response.roles {
                roles = r
            }
            currentUserId = response.currentUserId
            canManage = response.canManage
            canManageOwners = response.canManageOwners
            selectedSprintDays = response.settings.sprintDurationDays
        } catch let e as APIError {
            error = e.localizedDescription
        } catch {
            self.error = "Failed to load settings"
        }

        isLoading = false
    }

    private func saveSettings() async {
        guard let days = selectedSprintDays else { return }
        isSavingSettings = true
        settingsMessage = nil
        settingsError = nil

        do {
            let updated = try await ProjectAPIService.updateSprintDuration(projectId: projectId, days: days)
            settings = updated
            settingsMessage = "Settings saved"
        } catch let e as APIError {
            settingsError = e.localizedDescription
        } catch {
            settingsError = "Failed to save settings"
        }

        isSavingSettings = false
    }

    private func changeRole(_ member: ProjectMember, to newRole: String) async {
        busyMemberId = member.userId
        memberError = nil

        do {
            members = try await ProjectAPIService.changeMemberRole(projectId: projectId, userId: member.userId, role: newRole)
        } catch let e as APIError {
            memberError = e.localizedDescription
        } catch {
            memberError = "Failed to change role"
        }

        busyMemberId = nil
    }

    private func removeMember(_ member: ProjectMember) async {
        busyMemberId = member.userId
        memberError = nil

        do {
            members = try await ProjectAPIService.removeMember(projectId: projectId, userId: member.userId)
            // If we left the project, dismiss
            if member.userId == currentUserId {
                dismiss()
            }
        } catch let e as APIError {
            memberError = e.localizedDescription
        } catch {
            memberError = "Failed to remove member"
        }

        busyMemberId = nil
    }

    private func sendInvite() async {
        isInviting = true
        inviteMessage = nil
        inviteError = nil

        do {
            let response = try await ProjectAPIService.inviteMember(
                projectId: projectId,
                identifier: inviteIdentifier.trimmingCharacters(in: .whitespaces),
                role: inviteRole
            )
            members = response.members
            inviteMessage = response.message ?? "Invite sent"
            inviteIdentifier = ""
        } catch let e as APIError {
            inviteError = e.localizedDescription
        } catch {
            inviteError = "Failed to send invite"
        }

        isInviting = false
    }
}

#Preview {
    NavigationStack {
        ProjectSettingsView(projectId: 1)
    }
}
