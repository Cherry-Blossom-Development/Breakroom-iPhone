import SwiftUI
import AVFoundation

private let monthNames = [
    "", "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
]

struct SessionsView: View {
    // MARK: - State

    @State private var sessions: [Session] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Year filter (nil = All)
    @State private var selectedYear: Int?

    // Recording
    @State private var recordingState: RecordingState = .idle
    @State private var recordingSeconds = 0
    @State private var pendingRecordingURL: URL?
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingTimer: Timer?

    // Playback
    @State private var nowPlayingId: Int?
    @State private var nowPlayingName: String?
    @State private var nowPlayingURL: URL?
    @State private var audioPlayer: AVPlayer?

    // Rating popup
    @State private var ratingSessionId: Int?
    @State private var showRatingPopup = false

    // Edit session
    @State private var editingSession: Session?

    // Delete confirmation
    @State private var sessionToDelete: Session?

    // Save recording sheet
    @State private var showSaveSheet = false

    // MARK: - Computed Properties

    private var availableYears: [Int] {
        let years = Set(sessions.map { $0.year })
        return years.sorted(by: >)
    }

    private var filteredSessions: [Session] {
        guard let year = selectedYear else { return sessions }
        return sessions.filter { $0.year == year }
    }

    private var groupedSessions: [(year: Int, months: [(month: Int, sessions: [Session])])] {
        let byYear = Dictionary(grouping: filteredSessions) { $0.year }
        return byYear.keys.sorted(by: >).map { year in
            let yearSessions = byYear[year]!
            let byMonth = Dictionary(grouping: yearSessions) { $0.month }
            let months = byMonth.keys.sorted(by: >).map { month in
                (month: month, sessions: byMonth[month]!.sorted { ($0.recordedAt ?? $0.uploadedAt) > ($1.recordedAt ?? $1.uploadedAt) })
            }
            return (year: year, months: months)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header with record button
                headerView

                // Year tabs
                if !availableYears.isEmpty {
                    yearTabsView
                }

                // Content
                if isLoading && sessions.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if sessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }

            // Now Playing bar
            if nowPlayingId != nil {
                VStack {
                    Spacer()
                    nowPlayingBar
                }
            }
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSessions()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showSaveSheet) {
            saveRecordingSheet
        }
        .sheet(isPresented: $showRatingPopup) {
            ratingPopupSheet
        }
        .sheet(item: $editingSession) { session in
            editSessionSheet(session: session)
        }
        .alert("Delete Session", isPresented: .constant(sessionToDelete != nil)) {
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    Task { await deleteSession(session) }
                }
                sessionToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete \"\(sessionToDelete?.name ?? "")\"? This cannot be undone.")
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Text("Sessions")
                .font(.largeTitle.bold())
                .foregroundStyle(.purple)

            Spacer()

            recordButton
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var recordButton: some View {
        switch recordingState {
        case .idle:
            Button {
                Task { await startRecording() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                    Text("Record")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

        case .recording:
            HStack(spacing: 8) {
                Text(formatDuration(recordingSeconds))
                    .foregroundStyle(.red)
                    .fontWeight(.bold)
                    .monospacedDigit()

                Button {
                    stopRecording()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

        case .saving:
            ProgressView()
                .frame(width: 32, height: 32)
        }
    }

    // MARK: - Year Tabs

    private var yearTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableYears, id: \.self) { year in
                    Button {
                        selectedYear = year
                    } label: {
                        Text(String(year))
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedYear == year ? Color.purple : Color(UIColor.secondarySystemBackground))
                            .foregroundStyle(selectedYear == year ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }

                Button {
                    selectedYear = nil
                } label: {
                    Text("All")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedYear == nil ? Color.purple : Color(UIColor.secondarySystemBackground))
                        .foregroundStyle(selectedYear == nil ? .white : .primary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Sessions", systemImage: "mic")
        } description: {
            Text("Tap the Record button to get started")
        }
    }

    // MARK: - Session List

    private var sessionListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groupedSessions, id: \.year) { yearGroup in
                    // Year header
                    Text(String(yearGroup.year))
                        .font(.title2.weight(.bold))
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 4)

                    ForEach(yearGroup.months, id: \.month) { monthGroup in
                        // Month header
                        VStack(alignment: .leading, spacing: 0) {
                            Text(monthNames[monthGroup.month])
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.purple)
                                .padding(.horizontal)
                                .padding(.top, 12)
                                .padding(.bottom, 4)

                            Divider()
                                .padding(.horizontal)

                            // Sessions in this month
                            ForEach(monthGroup.sessions) { session in
                                SessionRow(
                                    session: session,
                                    isPlaying: nowPlayingId == session.id,
                                    onPlay: { playSession(session) },
                                    onRate: { openRatingPopup(session) },
                                    onEdit: { editingSession = session },
                                    onDelete: { sessionToDelete = session }
                                )

                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, nowPlayingId != nil ? 80 : 16)
        }
    }

    // MARK: - Now Playing Bar

    private var nowPlayingBar: some View {
        HStack {
            if nowPlayingURL == nil {
                ProgressView()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(.purple)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(nowPlayingName ?? "")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text(nowPlayingURL == nil ? "Loading..." : "Playing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                stopPlayback()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Save Recording Sheet

    private var saveRecordingSheet: some View {
        NavigationStack {
            SaveRecordingView(
                onSave: { name, date in
                    showSaveSheet = false
                    Task { await saveRecording(name: name, recordedAt: date) }
                },
                onDiscard: {
                    showSaveSheet = false
                    discardRecording()
                }
            )
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    // MARK: - Rating Popup Sheet

    private var ratingPopupSheet: some View {
        NavigationStack {
            RatingPopupView(
                currentRating: sessions.first { $0.id == ratingSessionId }?.myRating,
                onRate: { rating in
                    if let sessionId = ratingSessionId {
                        Task { await submitRating(sessionId: sessionId, rating: rating) }
                    }
                    showRatingPopup = false
                },
                onClear: {
                    if let sessionId = ratingSessionId {
                        Task { await submitRating(sessionId: sessionId, rating: nil) }
                    }
                    showRatingPopup = false
                },
                onDismiss: {
                    showRatingPopup = false
                }
            )
        }
        .presentationDetents([.height(280)])
    }

    // MARK: - Edit Session Sheet

    private func editSessionSheet(session: Session) -> some View {
        NavigationStack {
            EditSessionView(
                session: session,
                onSave: { name, date in
                    editingSession = nil
                    Task { await updateSession(sessionId: session.id, name: name, recordedAt: date) }
                },
                onCancel: {
                    editingSession = nil
                }
            )
        }
        .presentationDetents([.medium])
    }

    // MARK: - API Methods

    private func loadSessions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            sessions = try await SessionsAPIService.getSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSession(_ session: Session) async {
        do {
            try await SessionsAPIService.deleteSession(sessionId: session.id)
            sessions.removeAll { $0.id == session.id }
            if nowPlayingId == session.id {
                stopPlayback()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateSession(sessionId: Int, name: String, recordedAt: String?) async {
        do {
            let updated = try await SessionsAPIService.updateSession(
                sessionId: sessionId,
                name: name,
                recordedAt: recordedAt
            )
            if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
                sessions[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitRating(sessionId: Int, rating: Int?) async {
        do {
            let response = try await SessionsAPIService.rateSession(sessionId: sessionId, rating: rating)
            // Update the session in our list with new rating data
            if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
                let oldSession = sessions[index]
                // Create updated session with new rating info
                let updatedSession = Session(
                    id: oldSession.id,
                    name: oldSession.name,
                    s3Key: oldSession.s3Key,
                    fileSize: oldSession.fileSize,
                    mimeType: oldSession.mimeType,
                    uploadedAt: oldSession.uploadedAt,
                    recordedAt: oldSession.recordedAt,
                    avgRating: response.avgRating,
                    ratingCount: response.ratingCount,
                    myRating: response.myRating
                )
                sessions[index] = updatedSession
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Recording Methods

    private func startRecording() async {
        // Request microphone permission
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            errorMessage = "Microphone permission is required to record sessions"
            return
        }

        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)

            // Create temp file URL
            let tempDir = FileManager.default.temporaryDirectory
            let filename = "session_\(Date().timeIntervalSince1970).m4a"
            let fileURL = tempDir.appendingPathComponent(filename)

            // Recording settings (AAC, 44.1kHz, 128kbps - matching Android)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.record()
            pendingRecordingURL = fileURL

            recordingState = .recording
            recordingSeconds = 0

            // Start timer to update recording duration
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                recordingSeconds += 1
            }
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        audioRecorder?.stop()
        audioRecorder = nil

        recordingState = .saving
        showSaveSheet = true
    }

    private func saveRecording(name: String, recordedAt: String?) async {
        guard let fileURL = pendingRecordingURL else {
            recordingState = .idle
            return
        }

        do {
            let audioData = try Data(contentsOf: fileURL)
            let filename = fileURL.lastPathComponent

            let session = try await SessionsAPIService.uploadSession(
                audioData: audioData,
                filename: filename,
                name: name,
                recordedAt: recordedAt
            )

            sessions.insert(session, at: 0)

            // Clean up temp file
            try? FileManager.default.removeItem(at: fileURL)
            pendingRecordingURL = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        recordingState = .idle
    }

    private func discardRecording() {
        if let fileURL = pendingRecordingURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        pendingRecordingURL = nil
        recordingState = .idle
    }

    // MARK: - Playback Methods

    private func playSession(_ session: Session) {
        // If already playing this session, stop it
        if nowPlayingId == session.id {
            stopPlayback()
            return
        }

        // Stop any current playback
        stopPlayback()

        // Set up new playback
        nowPlayingId = session.id
        nowPlayingName = session.name
        nowPlayingURL = nil

        Task {
            do {
                // Configure audio session for playback
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)

                // Get stream URL
                let streamURL = try await SessionsAPIService.getStreamURL(sessionId: session.id)
                nowPlayingURL = streamURL

                // Create and play
                audioPlayer = AVPlayer(url: streamURL)
                audioPlayer?.play()
            } catch {
                await MainActor.run {
                    stopPlayback()
                    errorMessage = "Failed to play: \(error.localizedDescription)"
                }
            }
        }
    }

    private func stopPlayback() {
        audioPlayer?.pause()
        audioPlayer = nil
        nowPlayingId = nil
        nowPlayingName = nil
        nowPlayingURL = nil
    }

    // MARK: - Rating Methods

    private func openRatingPopup(_ session: Session) {
        ratingSessionId = session.id
        showRatingPopup = true
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let session: Session
    let isPlaying: Bool
    let onPlay: () -> Void
    let onRate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Play/Stop button
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(isPlaying ? .red : .purple)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            // Name + Date (tappable to edit)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.body)
                    .lineLimit(1)

                Text(session.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

            Spacer()

            // File size
            if !session.formattedFileSize.isEmpty {
                Text(session.formattedFileSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Rating chip
            RatingChip(
                avgRating: session.avgRating,
                ratingCount: session.ratingCount,
                myRating: session.myRating,
                onTap: onRate
            )

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Rating Chip

private struct RatingChip: View {
    let avgRating: Double?
    let ratingCount: Int
    let myRating: Int?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(chipText)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(myRating != nil ? Color.purple.opacity(0.2) : Color(UIColor.tertiarySystemFill))
                .foregroundStyle(myRating != nil ? .purple : .secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var chipText: String {
        if let avg = avgRating, ratingCount > 0 {
            return String(format: "★ %.1f (%d)", avg, ratingCount)
        }
        return "Rate"
    }
}

// MARK: - Save Recording View

private struct SaveRecordingView: View {
    let onSave: (String, String?) -> Void
    let onDiscard: () -> Void

    @State private var name: String
    @State private var date: String

    init(onSave: @escaping (String, String?) -> Void, onDiscard: @escaping () -> Void) {
        self.onSave = onSave
        self.onDiscard = onDiscard

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        _name = State(initialValue: "Session - \(today)")
        _date = State(initialValue: today)
    }

    var body: some View {
        Form {
            Section {
                TextField("Session name", text: $name)
                TextField("Date (YYYY-MM-DD)", text: $date)
            }
        }
        .navigationTitle("Save Recording")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Discard", role: .destructive, action: onDiscard)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(name, date.isEmpty ? nil : date)
                }
                .disabled(name.isEmpty)
            }
        }
    }
}

// MARK: - Rating Popup View

private struct RatingPopupView: View {
    let currentRating: Int?
    let onRate: (Int) -> Void
    let onClear: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Rate this session")
                .font(.headline)

            // 1-5
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { n in
                    ratingButton(n)
                }
            }

            // 6-10
            HStack(spacing: 12) {
                ForEach(6...10, id: \.self) { n in
                    ratingButton(n)
                }
            }

            if currentRating != nil {
                Button("Clear rating", action: onClear)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .navigationTitle("Rate Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onDismiss)
            }
        }
    }

    private func ratingButton(_ value: Int) -> some View {
        Button {
            onRate(value)
        } label: {
            Text("\(value)")
                .font(.body.weight(currentRating == value ? .bold : .regular))
                .frame(width: 40, height: 40)
                .background(currentRating == value ? Color.purple : Color(UIColor.tertiarySystemFill))
                .foregroundStyle(currentRating == value ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Session View

private struct EditSessionView: View {
    let session: Session
    let onSave: (String, String?) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var date: String

    init(session: Session, onSave: @escaping (String, String?) -> Void, onCancel: @escaping () -> Void) {
        self.session = session
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: session.name)
        _date = State(initialValue: session.formattedDate)
    }

    var body: some View {
        Form {
            Section {
                TextField("Session name", text: $name)
                TextField("Date (YYYY-MM-DD)", text: $date)
            }
        }
        .navigationTitle("Edit Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(name, date.isEmpty ? nil : date)
                }
                .disabled(name.isEmpty)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SessionsView()
    }
}
