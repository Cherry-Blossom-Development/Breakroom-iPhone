import SwiftUI

/// A dialog for reporting/flagging content.
/// Shows immediately when presented and calls the moderation API directly.
struct FlagDialogView: View {
    let contentType: ModerationContentType
    let contentId: Int?
    let onDismiss: () -> Void
    let onFlagged: () -> Void

    @State private var reason = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        if contentType.requiresReason {
            return !reason.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This content will be immediately hidden and reviewed by our moderation team.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    TextField("Describe the issue...", text: $reason, axis: .vertical)
                        .lineLimit(3...6)
                        .disabled(isSubmitting)
                } header: {
                    HStack {
                        Text("Reason")
                        if contentType.requiresReason {
                            Text("*")
                                .foregroundStyle(.red)
                        } else {
                            Text("(optional)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("Report Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task { await submitReport() }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .overlay {
                if isSubmitting {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView("Submitting...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func submitReport() async {
        isSubmitting = true
        errorMessage = nil

        do {
            try await ModerationAPIService.flagContent(
                contentType: contentType.rawValue,
                contentId: contentId,
                reason: reason.trimmingCharacters(in: .whitespaces).isEmpty ? nil : reason.trimmingCharacters(in: .whitespaces)
            )
            onFlagged()
            onDismiss()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to submit report. Please try again."
        }

        isSubmitting = false
    }
}

