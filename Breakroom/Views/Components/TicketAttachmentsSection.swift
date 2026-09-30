import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// Ticket attachments (migration 085), shared by the project board and the
// Help Desk (web: components/TicketAttachments.vue). Presentational: the
// caller decides whether picked files upload right away (Help Desk) or wait
// for Save Changes (board), and passes the pending state back in.

let maxAttachmentBytes: Int64 = 25 * 1024 * 1024  // 25 MB
let maxAttachmentFiles = 10

/// A picked file that hasn't been uploaded yet
struct PendingFile: Identifiable {
    let id = UUID()
    let data: Data
    let fileName: String
    let mimeType: String

    var size: Int64 { Int64(data.count) }

    var isImage: Bool {
        let imageTypes = ["image/png", "image/jpeg", "image/gif", "image/webp"]
        return imageTypes.contains(mimeType)
    }
}

/// Ticket attachments section for the ticket detail view
struct TicketAttachmentsSection: View {
    let attachments: [TicketAttachment]
    @Binding var pendingFiles: [PendingFile]
    @Binding var pendingRemovals: Set<Int>
    let canAttach: Bool
    let canRemove: (TicketAttachment) -> Bool
    let busy: Bool
    let error: String?
    let onOpen: (TicketAttachment) -> Void

    @State private var localError: String?
    @State private var showFilePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Attachments")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if canAttach {
                    Button {
                        localError = nil
                        showFilePicker = true
                    } label: {
                        Label(busy ? "Uploading..." : "Attach files", systemImage: "paperclip")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(busy)
                }
            }

            // Empty state
            if attachments.isEmpty && pendingFiles.isEmpty {
                Text(canAttach ? "No attachments. Tap Attach files (up to 25 MB each)." : "No attachments.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Existing attachments
            ForEach(attachments) { attachment in
                let isRemoving = pendingRemovals.contains(attachment.id)
                attachmentRow(
                    attachment: attachment,
                    isRemoving: isRemoving,
                    canRemove: canRemove(attachment)
                )
            }

            // Pending files (not yet saved)
            ForEach(Array(pendingFiles.enumerated()), id: \.element.id) { index, file in
                pendingFileRow(file: file, index: index)
            }

            // Error message
            if let error = localError ?? error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            handleFilePicked(result)
        }
    }

    // MARK: - Attachment Row

    private func attachmentRow(attachment: TicketAttachment, isRemoving: Bool, canRemove: Bool) -> some View {
        HStack(spacing: 12) {
            // Thumbnail or icon
            if attachment.isImage {
                // For images, we'd show a thumbnail - for now just show icon
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "doc")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.subheadline)
                    .foregroundStyle(isRemoving ? .secondary : Color.accentColor)
                    .strikethrough(isRemoving)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(attachment.formattedSize)
                    if let uploader = attachment.uploaderHandle {
                        Text("·")
                        Text("@\(uploader)")
                    }
                    if isRemoving {
                        Text("· removing")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Actions
            if isRemoving {
                Button("Undo") {
                    pendingRemovals.remove(attachment.id)
                }
                .font(.caption)
            } else if canRemove {
                Button {
                    pendingRemovals.insert(attachment.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(busy)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isRemoving {
                onOpen(attachment)
            }
        }
    }

    // MARK: - Pending File Row

    private func pendingFileRow(file: PendingFile, index: Int) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: file.isImage ? "photo" : "doc")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.subheadline)
                    .lineLimit(1)

                Text("\(formatFileSize(file.size)) · unsaved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            Spacer()

            // Remove button
            Button {
                pendingFiles.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(busy)
        }
    }

    // MARK: - File Handling

    private func handleFilePicked(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var newFiles: [PendingFile] = []

            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                do {
                    let data = try Data(contentsOf: url)
                    let fileName = url.lastPathComponent
                    let mimeType = mimeTypeForURL(url)

                    newFiles.append(PendingFile(
                        data: data,
                        fileName: fileName,
                        mimeType: mimeType
                    ))
                } catch {
                    localError = "Failed to read file: \(url.lastPathComponent)"
                    return
                }
            }

            // Check limits
            if let limitError = attachmentLimitError(newFiles, alreadyPending: pendingFiles.count) {
                localError = limitError
                return
            }

            pendingFiles.append(contentsOf: newFiles)

        case .failure(let error):
            localError = "Failed to pick files: \(error.localizedDescription)"
        }
    }

    private func mimeTypeForURL(_ url: URL) -> String {
        if let uti = UTType(filenameExtension: url.pathExtension) {
            return uti.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }
}

// MARK: - Helper Functions

func formatFileSize(_ bytes: Int64) -> String {
    if bytes < 1024 {
        return "\(bytes) B"
    } else if bytes < 1024 * 1024 {
        return "\(bytes / 1024) KB"
    } else {
        return String(format: "%.1f MB", Double(bytes) / 1024.0 / 1024.0)
    }
}

func attachmentLimitError(_ files: [PendingFile], alreadyPending: Int = 0) -> String? {
    let tooBig = files.filter { $0.size > maxAttachmentBytes }
    if !tooBig.isEmpty {
        let names = tooBig.map { $0.fileName }.joined(separator: ", ")
        return "\(names) \(tooBig.count == 1 ? "is" : "are") over 25 MB"
    }

    if files.count + alreadyPending > maxAttachmentFiles {
        return "Attach at most \(maxAttachmentFiles) files at a time"
    }

    return nil
}

#Preview {
    TicketAttachmentsSection(
        attachments: [],
        pendingFiles: .constant([]),
        pendingRemovals: .constant([]),
        canAttach: true,
        canRemove: { _ in true },
        busy: false,
        error: nil,
        onOpen: { _ in }
    )
    .padding()
}
