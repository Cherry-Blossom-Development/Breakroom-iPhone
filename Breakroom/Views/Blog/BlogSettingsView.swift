import SwiftUI

struct BlogSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var blogName = ""
    @State private var blogUrl = ""
    @State private var existingSettings: BlogSettings?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var urlCheckStatus: URLCheckStatus = .idle
    @State private var urlCheckTask: Task<Void, Never>?

    enum URLCheckStatus: Equatable {
        case idle
        case checking
        case available
        case taken
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Blog Details") {
                    TextField("Blog Name", text: $blogName)
                    TextField("Blog URL", text: $blogUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: blogUrl) { _, newValue in
                            checkURLAvailability(newValue)
                        }

                    if urlCheckStatus != .idle {
                        HStack(spacing: 6) {
                            switch urlCheckStatus {
                            case .checking:
                                ProgressView()
                                    .controlSize(.small)
                                Text("Checking availability...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            case .available:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                Text("URL is available")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            case .taken:
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                                Text("URL is taken")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            case .idle:
                                EmptyView()
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Blog Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(
                        blogName.trimmingCharacters(in: .whitespaces).isEmpty ||
                        blogUrl.trimmingCharacters(in: .whitespaces).isEmpty ||
                        isSaving ||
                        urlCheckStatus == .taken ||
                        urlCheckStatus == .checking
                    )
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .task {
                await loadSettings()
            }
        }
    }

    private func loadSettings() async {
        do {
            let settings = try await BlogAPIService.getSettings()
            existingSettings = settings
            if let settings {
                blogName = settings.blogName
                blogUrl = settings.blogUrl
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func checkURLAvailability(_ url: String) {
        urlCheckTask?.cancel()

        let trimmed = url.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            urlCheckStatus = .idle
            return
        }

        if trimmed == existingSettings?.blogUrl {
            urlCheckStatus = .available
            return
        }

        urlCheckStatus = .checking
        urlCheckTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }

            do {
                let available = try await BlogAPIService.checkURL(blogUrl: trimmed)
                if !Task.isCancelled {
                    urlCheckStatus = available ? .available : .taken
                }
            } catch {
                if !Task.isCancelled {
                    urlCheckStatus = .idle
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil

        let trimmedUrl = blogUrl.trimmingCharacters(in: .whitespaces)
        let trimmedName = blogName.trimmingCharacters(in: .whitespaces)

        do {
            if existingSettings != nil {
                existingSettings = try await BlogAPIService.updateSettings(
                    blogUrl: trimmedUrl,
                    blogName: trimmedName
                )
            } else {
                existingSettings = try await BlogAPIService.createSettings(
                    blogUrl: trimmedUrl,
                    blogName: trimmedName
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
