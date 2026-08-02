import SwiftUI

/// A button that shows a popover for adding/removing a session from shortlists
struct ShortlistButton: View {
    let session: Session
    let bands: [Band] // Active bands the user is in

    @State private var showPopover = false
    @State private var shortlists: [Shortlist] = []
    @State private var sessionShortlistIds: [Int] = []
    @State private var isLoading = false
    @State private var error: String?

    // Create new shortlist
    @State private var newName = ""
    @State private var newBandId: Int?
    @State private var isCreating = false

    private var isShortlisted: Bool {
        !sessionShortlistIds.isEmpty || session.isShortlisted
    }

    var body: some View {
        Button {
            showPopover = true
        } label: {
            Image(systemName: isShortlisted ? "bookmark.fill" : "bookmark")
                .font(.caption)
                .foregroundStyle(isShortlisted ? .purple : .secondary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isShortlisted ? "Remove from shortlist" : "Add to shortlist")
        .accessibilityIdentifier("shortlistButton_\(session.id)")
        .popover(isPresented: $showPopover) {
            shortlistPopover
                .frame(width: 280)
                .presentationCompactAdaptation(.popover)
        }
    }

    private var shortlistPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADD TO SHORTLIST")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .kerning(0.5)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if shortlists.isEmpty {
                Text("No shortlists yet — create one below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(shortlists) { shortlist in
                    shortlistRow(shortlist)
                }
            }

            Divider()

            // Create new shortlist section
            VStack(spacing: 8) {
                if bands.count > 1 {
                    Picker("Band", selection: $newBandId) {
                        ForEach(bands) { band in
                            Text(band.name).tag(band.id as Int?)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                }

                HStack {
                    TextField("New shortlist name...", text: $newName)
                        .font(.caption)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { createAndAdd() }

                    Button {
                        createAndAdd()
                    } label: {
                        Text(isCreating ? "..." : "+ Add")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .task {
            await loadShortlists()
        }
        .onAppear {
            if newBandId == nil, let firstBand = bands.first {
                newBandId = session.bandId ?? firstBand.id
            }
        }
    }

    private func shortlistRow(_ shortlist: Shortlist) -> some View {
        Button {
            Task { await toggleShortlist(shortlist) }
        } label: {
            HStack {
                Image(systemName: sessionShortlistIds.contains(shortlist.id) ? "checkmark.square.fill" : "square")
                    .foregroundStyle(sessionShortlistIds.contains(shortlist.id) ? .purple : .secondary)

                Text(shortlist.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Text(shortlist.bandName ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func loadShortlists() async {
        isLoading = true
        error = nil

        do {
            async let shortlistsResult = SessionsAPIService.getMyShortlists()
            async let idsResult = SessionsAPIService.getSessionShortlistIds(sessionId: session.id)

            shortlists = try await shortlistsResult
            sessionShortlistIds = try await idsResult
        } catch {
            self.error = "Failed to load shortlists"
        }

        isLoading = false
    }

    private func toggleShortlist(_ shortlist: Shortlist) async {
        error = nil
        let wasInShortlist = sessionShortlistIds.contains(shortlist.id)

        do {
            if wasInShortlist {
                try await SessionsAPIService.removeSessionFromShortlist(
                    shortlistId: shortlist.id,
                    sessionId: session.id
                )
                sessionShortlistIds.removeAll { $0 == shortlist.id }
            } else {
                try await SessionsAPIService.addSessionToShortlist(
                    shortlistId: shortlist.id,
                    sessionId: session.id
                )
                sessionShortlistIds.append(shortlist.id)
            }
        } catch {
            self.error = wasInShortlist ? "Failed to remove" : "Failed to add"
        }
    }

    private func createAndAdd() {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty,
              let bandId = newBandId,
              !isCreating else { return }

        isCreating = true
        error = nil

        Task {
            do {
                let newShortlist = try await SessionsAPIService.createShortlist(
                    bandId: bandId,
                    name: newName.trimmingCharacters(in: .whitespaces)
                )
                shortlists.append(newShortlist)

                try await SessionsAPIService.addSessionToShortlist(
                    shortlistId: newShortlist.id,
                    sessionId: session.id
                )
                sessionShortlistIds.append(newShortlist.id)

                newName = ""
            } catch {
                self.error = "Failed to create shortlist"
            }
            isCreating = false
        }
    }
}
