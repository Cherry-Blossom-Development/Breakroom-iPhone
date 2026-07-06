import Foundation
import SwiftUI

@MainActor
@Observable
final class BandPageSetupViewModel {
    let bandId: Int

    // Loading state
    var isLoading = true
    var errorMessage: String?
    var saveMessage: String?

    // Band page data
    var bandName = ""
    var bandUrl = ""
    var story = ""
    var backgroundColor = ""
    var backgroundPhotoUrl: String?
    var isPublished = false

    // Members and instruments
    var members: [BandPageMember] = []
    var instruments: [Instrument] = []
    var savingMemberIds: Set<Int> = []

    // Songs
    var songs: [BandPageSession] = []

    // Saving state
    var isSavingSettings = false
    var isUploadingBackground = false

    init(bandId: Int) {
        self.bandId = bandId
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try await SessionsAPIService.getBandPage(bandId: bandId)
            bandName = data.bandName
            bandUrl = data.bandUrl ?? ""
            story = data.story ?? ""
            backgroundColor = data.backgroundColor ?? ""
            backgroundPhotoUrl = data.backgroundPhotoUrl
            isPublished = data.isPublished
            members = data.members
            instruments = data.instruments
            songs = data.sessions
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Settings

    func updateBandUrl(_ value: String) {
        // Sanitize: lowercase, letters, numbers, hyphens only
        bandUrl = value.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    func updateStory(_ value: String) {
        story = value
    }

    func updateBackgroundColor(_ value: String) {
        backgroundColor = value
    }

    func updatePublished(_ value: Bool) {
        isPublished = value
        Task { await saveSettings() }
    }

    func saveSettings() async {
        isSavingSettings = true
        errorMessage = nil
        saveMessage = nil

        do {
            try await SessionsAPIService.updateBandPage(
                bandId: bandId,
                bandUrl: bandUrl.trimmingCharacters(in: .whitespaces).isEmpty ? nil : bandUrl.trimmingCharacters(in: .whitespaces),
                story: story.trimmingCharacters(in: .whitespaces).isEmpty ? nil : story.trimmingCharacters(in: .whitespaces),
                backgroundColor: backgroundColor.isEmpty ? nil : backgroundColor,
                isPublished: isPublished
            )
            saveMessage = "Settings saved"

            // Clear save message after delay
            Task {
                try? await Task.sleep(for: .seconds(3))
                saveMessage = nil
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isSavingSettings = false
    }

    // MARK: - Background Photo

    func uploadBackground(imageData: Data) async {
        isUploadingBackground = true
        errorMessage = nil

        do {
            let response = try await SessionsAPIService.uploadBandPageBackground(bandId: bandId, imageData: imageData)
            backgroundPhotoUrl = response.backgroundPhotoUrl
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isUploadingBackground = false
    }

    func removeBackground() async {
        isUploadingBackground = true
        errorMessage = nil

        do {
            try await SessionsAPIService.deleteBandPageBackground(bandId: bandId)
            backgroundPhotoUrl = nil
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isUploadingBackground = false
    }

    // MARK: - Member Instruments

    func toggleInstrument(for member: BandPageMember, instrumentId: Int) {
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return }

        var newIds = members[index].instrumentIds
        if newIds.contains(instrumentId) {
            newIds.removeAll { $0 == instrumentId }
        } else {
            newIds.append(instrumentId)
        }

        members[index].instrumentIds = newIds
        savingMemberIds.insert(member.id)

        Task {
            do {
                try await SessionsAPIService.setBandPageMemberInstruments(
                    bandId: bandId,
                    userId: member.id,
                    instrumentIds: newIds
                )
            } catch let error as APIError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            savingMemberIds.remove(member.id)
        }
    }

    // MARK: - Songs

    func toggleSong(_ song: BandPageSession) {
        guard let index = songs.firstIndex(where: { $0.id == song.id }) else { return }
        songs[index].onPage.toggle()
        saveSongs()
    }

    func moveSong(_ song: BandPageSession, direction: Int) {
        let featured = songs.filter { $0.onPage }.sorted { $0.displayOrder < $1.displayOrder }
        guard let idx = featured.firstIndex(where: { $0.id == song.id }) else { return }

        let swapIdx = idx + direction
        guard swapIdx >= 0 && swapIdx < featured.count else { return }

        let a = featured[idx]
        let b = featured[swapIdx]

        // Swap display orders
        if let aIndex = songs.firstIndex(where: { $0.id == a.id }),
           let bIndex = songs.firstIndex(where: { $0.id == b.id }) {
            let aOrder = songs[aIndex].displayOrder
            let bOrder = songs[bIndex].displayOrder
            songs[aIndex].displayOrder = bOrder
            songs[bIndex].displayOrder = aOrder
        }

        saveSongs()
    }

    private func saveSongs() {
        let orderedIds = songs
            .filter { $0.onPage }
            .sorted { $0.displayOrder < $1.displayOrder }
            .map { $0.id }

        Task {
            do {
                try await SessionsAPIService.setBandPageSongs(bandId: bandId, sessionIds: orderedIds)
            } catch let error as APIError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Helpers

    func clearError() {
        errorMessage = nil
    }

    func clearSaveMessage() {
        saveMessage = nil
    }

    /// Sorted songs: featured first (by display order), then non-featured
    var sortedSongs: [BandPageSession] {
        songs.sorted { lhs, rhs in
            if lhs.onPage != rhs.onPage {
                return lhs.onPage
            }
            return lhs.displayOrder < rhs.displayOrder
        }
    }

    /// Public URL for the band page
    var publicUrl: String? {
        guard isPublished, !bandUrl.isEmpty else { return nil }
        return "\(Config.baseURL)/band/\(bandUrl)"
    }
}
