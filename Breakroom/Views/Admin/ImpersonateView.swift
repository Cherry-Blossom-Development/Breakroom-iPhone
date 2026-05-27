import SwiftUI

struct ImpersonateView: View {
    let onImpersonated: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var users: [SearchUser] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var searchQuery = ""
    @State private var impersonatingId: Int?
    @State private var impersonationError: String?

    private var filteredUsers: [SearchUser] {
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return users
        }
        let query = searchQuery.lowercased()
        return users.filter {
            $0.handle.lowercased().contains(query) ||
            $0.displayName.lowercased().contains(query) ||
            ($0.email?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search users...", text: $searchQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()

                // Error message
                if let impersonationError {
                    Text(impersonationError)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                // Content
                if isLoading {
                    Spacer()
                    ProgressView("Loading users...")
                    Spacer()
                } else if let error {
                    Spacer()
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await loadUsers() }
                        }
                    }
                    Spacer()
                } else if filteredUsers.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Users Found",
                        systemImage: "person.slash",
                        description: Text("No users match your search.")
                    )
                    Spacer()
                } else {
                    List(filteredUsers) { user in
                        userRow(user)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Impersonate User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadUsers()
            }
        }
    }

    @ViewBuilder
    private func userRow(_ user: SearchUser) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.body)
                Text("@\(user.handle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if impersonatingId == user.id {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Impersonate") {
                    Task { await startImpersonation(user) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(impersonatingId != nil)
            }
        }
        .padding(.vertical, 4)
    }

    private func loadUsers() async {
        isLoading = true
        error = nil
        do {
            users = try await AdminAPIService.getAllUsers()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func startImpersonation(_ user: SearchUser) async {
        impersonatingId = user.id
        impersonationError = nil

        do {
            _ = try await AdminAPIService.startImpersonation(userId: user.id)
            onImpersonated()
            dismiss()
        } catch {
            impersonationError = error.localizedDescription
        }

        impersonatingId = nil
    }
}

#Preview {
    ImpersonateView(onImpersonated: {})
}
