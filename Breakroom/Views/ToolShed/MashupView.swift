import SwiftUI
import AVFoundation

enum MashupState: Equatable {
    case selectingBacking
    case preparingBacking
    case readyToRecord
    case recording
    case processingRecording
    case adjusting
    case generatingPreview
    case previewing
    case saving
    case saved
}

struct MashupView: View {
    // MARK: - Input Data

    let ownSessions: [Session]
    let bandMemberSessions: [Session]
    let bands: [Band]
    let instruments: [Instrument]

    // MARK: - State

    @State private var mashupState: MashupState = .selectingBacking
    @State private var backingSession: Session?
    @State private var backingAudioURL: URL?
    @State private var recordedURL: URL?
    @State private var normalizedRecordingURL: URL?
    @State private var mixedURL: URL?

    @State private var backingVolume: Float = 1.0
    @State private var recordingVolume: Float = 1.0

    @State private var recordingSeconds: Int = 0
    @State private var recordingTimer: Timer?
    @State private var audioRecorder: AVAudioRecorder?
    @State private var backingPlayer: AVAudioPlayer?
    @State private var previewPlayer: AVAudioPlayer?

    @State private var errorMessage: String?
    @State private var showSaveSheet = false
    @State private var savedSession: Session?
    @State private var linkCopied = false

    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed Properties

    private var availableSessions: [Session] {
        // Combine own individual sessions with band member sessions (exclude mashups)
        let ownIndividual = ownSessions.filter { $0.isIndividual }
        let bandNonMashups = bandMemberSessions.filter { !$0.isMashup }
        return ownIndividual + bandNonMashups
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            switch mashupState {
            case .selectingBacking:
                backingSelectionView

            case .preparingBacking:
                preparingView(message: "Downloading backing track...")

            case .readyToRecord, .recording:
                recordingView

            case .processingRecording:
                preparingView(message: "Processing recording...")

            case .adjusting:
                adjustingView

            case .generatingPreview:
                preparingView(message: "Generating preview...")

            case .previewing:
                previewView

            case .saving:
                preparingView(message: "Saving mashup...")

            case .saved:
                savedView
            }
        }
        .navigationTitle("Create Mashup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    cleanup()
                    dismiss()
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showSaveSheet) {
            saveMashupSheet
        }
        .onDisappear {
            cleanup()
        }
    }

    // MARK: - Backing Selection View

    private var backingSelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select a backing track to record over")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if availableSessions.isEmpty {
                ContentUnavailableView {
                    Label("No Sessions Available", systemImage: "music.note.list")
                } description: {
                    Text("Record individual sessions or join a band to create mashups")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(availableSessions) { session in
                            backingSessionRow(session)
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
            }
        }
        .padding(.top)
    }

    private func backingSessionRow(_ session: Session) -> some View {
        Button {
            selectBackingTrack(session)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(.purple)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let instrument = session.instrumentName {
                            Text(instrument)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let handle = session.uploaderHandle {
                            Text("@\(handle)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Text(session.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recording View

    private var recordingView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Backing track info
            if let session = backingSession {
                VStack(spacing: 8) {
                    Text("Recording over:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(session.name)
                        .font(.title3.weight(.semibold))
                }
            }

            // Recording timer
            Text(formatDuration(recordingSeconds))
                .font(.system(size: 72, weight: .light, design: .monospaced))
                .foregroundStyle(mashupState == .recording ? .red : .primary)

            // Record/Stop button
            Button {
                if mashupState == .recording {
                    stopRecording()
                } else {
                    Task { await startRecording() }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(mashupState == .recording ? Color.red : Color.purple)
                        .frame(width: 80, height: 80)

                    if mashupState == .recording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 28, height: 28)
                    } else {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 32, height: 32)
                    }
                }
            }
            .accessibilityLabel(mashupState == .recording ? "Stop Recording" : "Start Recording")

            Text(mashupState == .recording ? "Tap to stop" : "Tap to start recording")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Back button (only when not recording)
            if mashupState == .readyToRecord {
                Button("Choose Different Track") {
                    backingSession = nil
                    if let url = backingAudioURL {
                        try? FileManager.default.removeItem(at: url)
                        backingAudioURL = nil
                    }
                    mashupState = .selectingBacking
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom)
            }
        }
        .padding()
    }

    // MARK: - Adjusting View

    private var adjustingView: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Adjust Volume Levels")
                .font(.title2.weight(.semibold))

            VStack(spacing: 24) {
                // Backing track volume
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Backing Track")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(Int(backingVolume * 100))%")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(value: $backingVolume, in: 0...1, step: 0.05)
                        .tint(.purple)
                }

                // Recording volume
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Your Recording")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(Int(recordingVolume * 100))%")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(value: $recordingVolume, in: 0...1, step: 0.05)
                        .tint(.purple)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await generatePreview() }
                } label: {
                    Text("Preview Mix")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button("Re-record") {
                    cleanupRecording()
                    mashupState = .readyToRecord
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: - Preview View

    private var previewView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "waveform")
                .font(.system(size: 64))
                .foregroundStyle(.purple)

            Text("Preview Ready")
                .font(.title2.weight(.semibold))

            // Playback controls
            HStack(spacing: 24) {
                Button {
                    playPreview()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title)
                        .frame(width: 60, height: 60)
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }

                Button {
                    stopPreview()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title)
                        .frame(width: 60, height: 60)
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(Circle())
                }

                if let url = mixedURL {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title)
                            .frame(width: 60, height: 60)
                            .background(Color(.secondarySystemBackground))
                            .foregroundStyle(.primary)
                            .clipShape(Circle())
                    }
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    stopPreview()
                    showSaveSheet = true
                } label: {
                    Text("Save Mashup")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button("Adjust Levels") {
                    stopPreview()
                    if let url = mixedURL {
                        try? FileManager.default.removeItem(at: url)
                        mixedURL = nil
                    }
                    mashupState = .adjusting
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: - Preparing View

    private func preparingView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Saved View

    private var savedView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Mashup Saved!")
                .font(.title2.weight(.semibold))

            if let session = savedSession {
                VStack(spacing: 16) {
                    // Share link button
                    Button {
                        let link = "https://www.prosaurus.com/sessions/\(session.id)"
                        UIPasteboard.general.string = link
                        linkCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            linkCopied = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: linkCopied ? "checkmark" : "link")
                            Text(linkCopied ? "Link Copied!" : "Copy Link")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(linkCopied ? .green : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Share via system share sheet
                    ShareLink(
                        item: URL(string: "https://www.prosaurus.com/sessions/\(session.id)")!,
                        subject: Text(session.name),
                        message: Text("Check out my mashup: \(session.name)")
                    ) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Link")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            Button("Done") {
                cleanup()
                dismiss()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: - Save Sheet

    private var saveMashupSheet: some View {
        NavigationStack {
            SaveMashupView(
                backingSession: backingSession,
                bands: bands,
                instruments: instruments,
                onSave: { name, bandId, instrumentId, saveAsIndividual in
                    showSaveSheet = false
                    Task { await saveMashup(name: name, bandId: bandId, instrumentId: instrumentId, saveAsIndividual: saveAsIndividual) }
                },
                onCancel: {
                    showSaveSheet = false
                }
            )
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    // MARK: - Actions

    private func selectBackingTrack(_ session: Session) {
        backingSession = session
        mashupState = .preparingBacking

        Task {
            do {
                let url = try await AudioMixer.downloadSessionAudio(sessionId: session.id)
                await MainActor.run {
                    backingAudioURL = url
                    mashupState = .readyToRecord
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to download backing track: \(error.localizedDescription)"
                    backingSession = nil
                    mashupState = .selectingBacking
                }
            }
        }
    }

    private func startRecording() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            errorMessage = "Microphone permission is required to record"
            return
        }

        do {
            // Configure audio session for playback + recording
            // Use .allowBluetoothA2DP to support Bluetooth headphones
            // Don't override output port - let iOS route to connected headphones
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .allowBluetooth])
            try audioSession.setActive(true)

            // Prepare recorder
            let tempDir = FileManager.default.temporaryDirectory
            let filename = "mashup_recording_\(Date().timeIntervalSince1970).m4a"
            let fileURL = tempDir.appendingPathComponent(filename)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recordedURL = fileURL

            // Prepare backing track player (using AVAudioPlayer for local files)
            if let backingURL = backingAudioURL {
                backingPlayer = try AVAudioPlayer(contentsOf: backingURL)
                backingPlayer?.volume = 1.0
                backingPlayer?.prepareToPlay()
            }

            // Start both
            recordingSeconds = 0
            mashupState = .recording

            audioRecorder?.record()
            backingPlayer?.play()

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
                Task { @MainActor in
                    recordingSeconds += 1
                }
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

        backingPlayer?.stop()
        backingPlayer = nil

        mashupState = .processingRecording

        Task {
            do {
                // Normalize the recording
                guard let recordingURL = recordedURL else {
                    throw AudioMixerError.fileNotFound
                }

                let normalizedURL = try AudioMixer.normalizeAudio(at: recordingURL)

                await MainActor.run {
                    normalizedRecordingURL = normalizedURL
                    mashupState = .adjusting
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to process recording: \(error.localizedDescription)"
                    mashupState = .readyToRecord
                }
            }
        }
    }

    private func generatePreview() async {
        mashupState = .generatingPreview

        do {
            guard let backingURL = backingAudioURL,
                  let recordingURL = normalizedRecordingURL else {
                throw AudioMixerError.fileNotFound
            }

            // Normalize backing track too
            let normalizedBackingURL = try AudioMixer.normalizeAudio(at: backingURL)

            let mixedURL = try AudioMixer.mixAudio(
                backing: normalizedBackingURL,
                backingVolume: backingVolume,
                recording: recordingURL,
                recordingVolume: recordingVolume
            )

            // Clean up intermediate file
            try? FileManager.default.removeItem(at: normalizedBackingURL)

            await MainActor.run {
                self.mixedURL = mixedURL
                mashupState = .previewing
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to generate preview: \(error.localizedDescription)"
                mashupState = .adjusting
            }
        }
    }

    private func playPreview() {
        guard let url = mixedURL else { return }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)

            previewPlayer = try AVAudioPlayer(contentsOf: url)
            previewPlayer?.prepareToPlay()
            previewPlayer?.play()
        } catch {
            errorMessage = "Failed to play preview: \(error.localizedDescription)"
        }
    }

    private func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
    }

    private func saveMashup(name: String, bandId: Int?, instrumentId: Int?, saveAsIndividual: Bool) async {
        mashupState = .saving

        do {
            guard let mixedURL = mixedURL,
                  let backingSession = backingSession else {
                throw AudioMixerError.fileNotFound
            }

            // If saveAsIndividual is enabled, first upload the raw recording as an individual session
            var individualSession: Session?
            if saveAsIndividual, let recordingURL = normalizedRecordingURL {
                let recordingData = try Data(contentsOf: recordingURL)
                let indivFilename = "recording_\(Date().timeIntervalSince1970).wav"

                // Generate individual session name
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let today = formatter.string(from: Date())
                let indivName = "\(backingSession.name) - Recording \(today)"

                individualSession = try await SessionsAPIService.uploadSession(
                    audioData: recordingData,
                    filename: indivFilename,
                    name: indivName,
                    recordedAt: nil,
                    bandId: bandId,
                    sessionType: "individual",
                    instrumentId: instrumentId
                )
            }

            // Upload the mashup
            let audioData = try Data(contentsOf: mixedURL)
            let filename = "mashup_\(Date().timeIntervalSince1970).wav"

            let mashupSession = try await SessionsAPIService.uploadSession(
                audioData: audioData,
                filename: filename,
                name: name,
                recordedAt: nil,
                bandId: bandId,
                sessionType: "mashup",
                instrumentId: instrumentId
            )

            // Record the source sessions used to create this mashup
            var sources = [MashupSourceEntry(sessionId: backingSession.id, volume: backingVolume)]
            if let indivSession = individualSession {
                sources.append(MashupSourceEntry(sessionId: indivSession.id, volume: recordingVolume))
            }
            try await SessionsAPIService.recordMashupSources(sessionId: mashupSession.id, sources: sources)

            await MainActor.run {
                savedSession = mashupSession
                mashupState = .saved
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save mashup: \(error.localizedDescription)"
                mashupState = .previewing
            }
        }
    }

    // MARK: - Cleanup

    private func cleanupRecording() {
        if let url = recordedURL {
            try? FileManager.default.removeItem(at: url)
            recordedURL = nil
        }
        if let url = normalizedRecordingURL {
            try? FileManager.default.removeItem(at: url)
            normalizedRecordingURL = nil
        }
        if let url = mixedURL {
            try? FileManager.default.removeItem(at: url)
            mixedURL = nil
        }
        recordingSeconds = 0
    }

    private func cleanup() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        audioRecorder?.stop()
        audioRecorder = nil

        backingPlayer?.stop()
        backingPlayer = nil

        previewPlayer?.stop()
        previewPlayer = nil

        // Clean up temp files
        var filesToClean: [URL] = []
        if let url = backingAudioURL { filesToClean.append(url) }
        if let url = recordedURL { filesToClean.append(url) }
        if let url = normalizedRecordingURL { filesToClean.append(url) }
        if let url = mixedURL { filesToClean.append(url) }
        AudioMixer.cleanupTempFiles(filesToClean)
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Save Mashup View

private struct SaveMashupView: View {
    let backingSession: Session?
    let bands: [Band]
    let instruments: [Instrument]
    let onSave: (String, Int?, Int?, Bool) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var selectedBandId: Int?
    @State private var selectedInstrumentId: Int?
    @State private var saveAsIndividual: Bool = false

    init(
        backingSession: Session?,
        bands: [Band],
        instruments: [Instrument],
        onSave: @escaping (String, Int?, Int?, Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.backingSession = backingSession
        self.bands = bands
        self.instruments = instruments
        self.onSave = onSave
        self.onCancel = onCancel

        let baseName = backingSession?.name ?? "Mashup"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        _name = State(initialValue: "\(baseName) - Mashup \(today)")
        _selectedBandId = State(initialValue: backingSession?.bandId)
    }

    var body: some View {
        Form {
            Section {
                TextField("Mashup name", text: $name)
            }

            Section {
                Picker("Band", selection: $selectedBandId) {
                    Text("No band").tag(nil as Int?)
                    ForEach(bands) { band in
                        Text(band.name).tag(band.id as Int?)
                    }
                }

                Picker("Instrument", selection: $selectedInstrumentId) {
                    Text("No instrument").tag(nil as Int?)
                    ForEach(instruments) { instrument in
                        Text(instrument.name).tag(instrument.id as Int?)
                    }
                }
            }

            Section {
                Toggle("Save recording as individual session", isOn: $saveAsIndividual)
            } footer: {
                Text("Also save your new recording separately as an individual session")
            }
        }
        .navigationTitle("Save Mashup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(name, selectedBandId, selectedInstrumentId, saveAsIndividual)
                }
                .disabled(name.isEmpty)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MashupView(
            ownSessions: [],
            bandMemberSessions: [],
            bands: [],
            instruments: []
        )
    }
}
