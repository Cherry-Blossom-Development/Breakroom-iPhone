import SwiftUI
import AVFoundation
import UIKit

private let monthNames = [
    "", "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
]

struct SessionsView: View {
    // MARK: - State

    @State private var selectedTab: SessionTab = .bandPractice

    // Sessions data
    @State private var sessions: [Session] = []
    @State private var bandMemberSessions: [Session] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Audio defaults
    @State private var audioDefaults = AudioDefaults.default
    @State private var showAudioDefaults = false

    // Device tracking
    @State private var currentDevice: UserDevice?
    @State private var deviceEditing = false
    @State private var deviceNameInput = ""
    @State private var deviceNameSaving = false

    // Subscription
    @State private var storeKitManager = StoreKitManager.shared
    @State private var showPaywall = false

    // Bands & Instruments
    @State private var bands: [Band] = []
    @State private var instruments: [Instrument] = []
    @State private var activeBand: Band?
    @State private var isLoadingBand = false

    // Year filter (nil = All)
    @State private var selectedYear: Int?
    @State private var indivSelectedYear: Int?
    @State private var bandMemberSelectedYear: Int?
    @State private var bandMemberBandFilter: Int?

    // Recording
    @State private var recordingState: RecordingState = .idle
    @State private var recordingSeconds = 0
    @State private var pendingRecordingURL: URL?
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingTimer: Timer?
    @State private var recordingContext: String = "band" // "band" or "individual"

    // Playback
    @State private var nowPlayingId: Int?
    @State private var nowPlayingName: String?
    @State private var nowPlayingURL: URL?
    @State private var audioPlayer: AVPlayer?

    // Dialogs
    @State private var showSaveSheet = false
    @State private var showRatingPopup = false
    @State private var ratingSessionId: Int?
    @State private var ratingSessionSource: String = "own" // "own" or "bandMember"
    @State private var editingSession: Session?
    @State private var sessionToDelete: Session?

    // Band management
    @State private var showCreateBand = false
    @State private var newBandName = ""
    @State private var newBandDescription = ""
    @State private var inviteHandle = ""
    @State private var inviteMessage: String?
    @State private var inviteError: String?
    @State private var editingBandName = false
    @State private var editBandNameValue = ""
    @State private var bandToDelete: Band?

    // MARK: - Computed Properties

    private var bandSessions: [Session] {
        sessions.filter { !$0.isIndividual }
    }

    private var individualSessions: [Session] {
        sessions.filter { $0.isIndividual }
    }

    private var activeBands: [Band] {
        bands.filter { $0.isActive }
    }

    private var pendingInvites: [Band] {
        bands.filter { $0.isInvited }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(SessionTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .accessibilityIdentifier("sessionsTabPicker")

            // Content based on tab
            switch selectedTab {
            case .bandPractice:
                bandPracticeTab
            case .individual:
                individualTab
            case .bands:
                bandsTab
            }
        }
        .accessibilityIdentifier("screenSessions")
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if !storeKitManager.isSubscribed {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                Text("Upgrade")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.purple)
                        }
                    }

                    Button {
                        showAudioDefaults = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
        }
        .sheet(isPresented: $showAudioDefaults) {
            AudioDefaultsSheet(
                defaults: $audioDefaults,
                currentDevice: currentDevice,
                deviceEditing: $deviceEditing,
                deviceNameInput: $deviceNameInput,
                deviceNameSaving: deviceNameSaving,
                onSave: { Task { await saveAudioDefaults() } },
                onStartRename: { startRenameDevice() },
                onCancelRename: { cancelRenameDevice() },
                onSaveDeviceName: { Task { await saveDeviceName() } }
            )
        }
        .task {
            await loadAllData()
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
            Text("Are you sure you want to delete \"\(sessionToDelete?.name ?? "")\"?")
        }
        .alert("Delete Band", isPresented: .constant(bandToDelete != nil)) {
            Button("Cancel", role: .cancel) { bandToDelete = nil }
            Button("Delete", role: .destructive) {
                if let band = bandToDelete {
                    Task { await deleteBand(band) }
                }
                bandToDelete = nil
            }
        } message: {
            Text("Delete \"\(bandToDelete?.name ?? "")\"? This cannot be undone.")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                onDismiss: {
                    showPaywall = false
                },
                onSubscribed: {
                    showPaywall = false
                }
            )
        }
    }

    // MARK: - Band Practice Tab

    private var bandPracticeTab: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Header with record button
                    recordingHeader(context: "band")

                    // Year tabs
                    yearTabs(
                        sessions: bandSessions,
                        selectedYear: $selectedYear
                    )

                    // Content
                    if isLoading && sessions.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if bandSessions.isEmpty {
                        emptyState(message: "No sessions yet", subtitle: "Tap Record to get started")
                    } else {
                        sessionsList(
                            sessions: bandSessions,
                            selectedYear: selectedYear,
                            showBandPicker: true,
                            showInstrumentPicker: false
                        )
                    }
                }
                .padding(.bottom, nowPlayingId != nil ? 80 : 16)
            }

            // Now Playing bar
            if nowPlayingId != nil {
                VStack {
                    Spacer()
                    nowPlayingBar
                }
            }
        }
    }

    // MARK: - Individual Tab

    private var individualTab: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // My Recordings section
                    sectionHeader("My Recordings")

                    recordingHeader(context: "individual")

                    yearTabs(
                        sessions: individualSessions,
                        selectedYear: $indivSelectedYear
                    )

                    if individualSessions.isEmpty {
                        emptyState(message: "No recordings yet", subtitle: "Record your individual practice")
                            .padding(.bottom, 24)
                    } else {
                        sessionsList(
                            sessions: individualSessions,
                            selectedYear: indivSelectedYear,
                            showBandPicker: true,
                            showInstrumentPicker: true
                        )
                    }

                    // Band Members section
                    sectionHeader("Band Members")

                    if !bandMemberSessions.isEmpty {
                        bandMemberFilters
                    }

                    if bandMemberSessions.isEmpty {
                        emptyState(message: "No band member recordings", subtitle: "Join a band to see their sessions")
                            .padding(.bottom, 24)
                    } else {
                        bandMemberSessionsList
                    }

                    // Mashups placeholder
                    sectionHeader("Mashups")
                    Text("Coming soon — combine individual parts into a mashup.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                }
                .padding(.bottom, nowPlayingId != nil ? 80 : 16)
            }

            if nowPlayingId != nil {
                VStack {
                    Spacer()
                    nowPlayingBar
                }
            }
        }
    }

    // MARK: - Bands Tab

    private var bandsTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Create band button
                HStack {
                    Text("Your Bands")
                        .font(.headline)
                    Spacer()
                    Button(showCreateBand ? "Cancel" : "+ New Band") {
                        showCreateBand.toggle()
                        newBandName = ""
                        newBandDescription = ""
                    }
                    .font(.subheadline.weight(.medium))
                    .accessibilityIdentifier("sessionsNewBandButton")
                }
                .padding(.horizontal)

                // Create band form
                if showCreateBand {
                    createBandForm
                }

                // Pending invites
                if !pendingInvites.isEmpty {
                    Text("Pending Invites")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)

                    ForEach(pendingInvites) { band in
                        inviteCard(band)
                    }
                }

                // Active bands
                if !activeBands.isEmpty {
                    Text("My Bands")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    ForEach(activeBands) { band in
                        bandListItem(band)
                    }
                } else if !isLoading && pendingInvites.isEmpty && !showCreateBand {
                    emptyState(message: "No bands yet", subtitle: "Create one or wait for an invite")
                }

                // Band detail
                if let band = activeBand {
                    Divider()
                        .padding(.vertical, 8)

                    bandDetailView(band)
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Components

    private func recordingHeader(context: String) -> some View {
        HStack {
            Text(context == "band" ? "Sessions" : "Record")
                .font(.title2.bold())
                .foregroundStyle(.purple)

            Spacer()

            recordButton(context: context)
        }
        .padding()
    }

    @ViewBuilder
    private func recordButton(context: String) -> some View {
        let isThisContext = (recordingState == .recording || recordingState == .saving) && recordingContext == context

        switch recordingState {
        case .idle:
            Button {
                recordingContext = context
                Task { await startRecording() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                    Text("Record")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .accessibilityIdentifier("sessionsRecordButton")

        case .recording where isThisContext:
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
                .accessibilityIdentifier("sessionsStopButton")
            }

        case .saving where isThisContext:
            ProgressView()
                .frame(width: 32, height: 32)

        default:
            // Recording in different context
            Button {} label: {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                    Text("Record")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(true)
        }
    }

    private func yearTabs(sessions: [Session], selectedYear: Binding<Int?>) -> some View {
        let years = Set(sessions.map { $0.year }).sorted(by: >)

        return Group {
            if !years.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(years, id: \.self) { year in
                            Button {
                                selectedYear.wrappedValue = year
                            } label: {
                                Text(String(year))
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedYear.wrappedValue == year ? Color.purple : Color(.secondarySystemBackground))
                                    .foregroundStyle(selectedYear.wrappedValue == year ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }

                        Button {
                            selectedYear.wrappedValue = nil
                        } label: {
                            Text("All")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedYear.wrappedValue == nil ? Color.purple : Color(.secondarySystemBackground))
                                .foregroundStyle(selectedYear.wrappedValue == nil ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func sessionsList(
        sessions: [Session],
        selectedYear: Int?,
        showBandPicker: Bool,
        showInstrumentPicker: Bool
    ) -> some View {
        let filtered = selectedYear == nil ? sessions : sessions.filter { $0.year == selectedYear }
        let grouped = groupSessions(filtered)

        return ForEach(grouped, id: \.year) { yearGroup in
            Text(String(yearGroup.year))
                .font(.title2.weight(.bold))
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 4)

            ForEach(yearGroup.months, id: \.month) { monthGroup in
                VStack(alignment: .leading, spacing: 0) {
                    Text(monthNames[monthGroup.month])
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.purple)
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                    Divider()
                        .padding(.horizontal)

                    ForEach(monthGroup.sessions) { session in
                        SessionRow(
                            session: session,
                            isPlaying: nowPlayingId == session.id,
                            bands: activeBands,
                            instruments: instruments,
                            showBandPicker: showBandPicker,
                            showInstrumentPicker: showInstrumentPicker,
                            onPlay: { playSession(session) },
                            onRate: { openRatingPopup(session, source: "own") },
                            onEdit: { editingSession = session },
                            onDelete: { sessionToDelete = session },
                            onBandChange: { bandId in
                                Task { await updateSessionBand(session, bandId: bandId) }
                            },
                            onInstrumentChange: { instrumentId in
                                Task { await updateSessionInstrument(session, instrumentId: instrumentId) }
                            }
                        )

                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
        }
    }

    private var bandMemberFilters: some View {
        HStack {
            // Band filter
            Menu {
                Button("All Bands") {
                    bandMemberBandFilter = nil
                }
                ForEach(bandMemberBands, id: \.id) { band in
                    Button(band.name) {
                        bandMemberBandFilter = band.id
                    }
                }
            } label: {
                HStack {
                    Text(bandMemberBandFilter == nil ? "All Bands" : (bandMemberBands.first { $0.id == bandMemberBandFilter }?.name ?? "All Bands"))
                        .font(.subheadline)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            // Year tabs (compact)
            let years = Set(filteredBandMemberSessions.map { $0.year }).sorted(by: >)
            if !years.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(years, id: \.self) { year in
                            Button {
                                bandMemberSelectedYear = year
                            } label: {
                                Text(String(year))
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(bandMemberSelectedYear == year ? Color.purple : Color(.secondarySystemBackground))
                                    .foregroundStyle(bandMemberSelectedYear == year ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                        Button {
                            bandMemberSelectedYear = nil
                        } label: {
                            Text("All")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(bandMemberSelectedYear == nil ? Color.purple : Color(.secondarySystemBackground))
                                .foregroundStyle(bandMemberSelectedYear == nil ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var bandMemberBands: [(id: Int, name: String)] {
        var seen = Set<Int>()
        var result: [(id: Int, name: String)] = []
        for session in bandMemberSessions {
            if let bandId = session.bandId, let bandName = session.bandName, !seen.contains(bandId) {
                seen.insert(bandId)
                result.append((id: bandId, name: bandName))
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    private var filteredBandMemberSessions: [Session] {
        if let bandId = bandMemberBandFilter {
            return bandMemberSessions.filter { $0.bandId == bandId }
        }
        return bandMemberSessions
    }

    private var bandMemberSessionsList: some View {
        let filtered = bandMemberSelectedYear == nil ? filteredBandMemberSessions : filteredBandMemberSessions.filter { $0.year == bandMemberSelectedYear }
        let grouped = groupSessions(filtered)

        return ForEach(grouped, id: \.year) { yearGroup in
            Text(String(yearGroup.year))
                .font(.title3.weight(.bold))
                .padding(.horizontal)
                .padding(.top, 12)

            ForEach(yearGroup.months, id: \.month) { monthGroup in
                VStack(alignment: .leading, spacing: 0) {
                    Text(monthNames[monthGroup.month])
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    Divider()
                        .padding(.horizontal)

                    ForEach(monthGroup.sessions) { session in
                        BandMemberSessionRow(
                            session: session,
                            isPlaying: nowPlayingId == session.id,
                            onPlay: { playSession(session) },
                            onRate: { openRatingPopup(session, source: "bandMember") }
                        )

                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 8)
            .padding(.leading, 8)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.purple)
                    .frame(width: 3)
                    .padding(.leading)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
            }
    }

    private func emptyState(message: String, subtitle: String) -> some View {
        ContentUnavailableView {
            Label(message, systemImage: "music.mic")
        } description: {
            Text(subtitle)
        }
        .frame(minHeight: 150)
        .accessibilityIdentifier("sessionsEmptyState")
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
        .accessibilityIdentifier("sessionsNowPlayingBar")
    }

    // MARK: - Band Components

    private var createBandForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create a Band")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Band Name", text: $newBandName)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("sessionsBandNameField")

            TextField("Description (optional)", text: $newBandDescription)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("sessionsBandDescriptionField")

            Button("Create Band") {
                Task { await createBand() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(newBandName.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityIdentifier("sessionsCreateBandButton")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func inviteCard(_ band: Band) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(band.name)
                    .font(.body.weight(.semibold))
            }

            Spacer()

            Button("Accept") {
                Task { await respondToInvite(band, action: "accept") }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("Decline") {
                Task { await respondToInvite(band, action: "decline") }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func bandListItem(_ band: Band) -> some View {
        Button {
            Task { await loadBandDetail(band.id) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(band.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("\(band.memberCount ?? 0) member\(band.memberCount == 1 ? "" : "s") • \(band.role ?? "member")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if activeBand?.id == band.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.purple)
                }
            }
            .padding()
            .background(activeBand?.id == band.id ? Color.purple.opacity(0.1) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(activeBand?.id == band.id ? Color.purple : Color.clear, lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }

    private func bandDetailView(_ band: Band) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Band name (editable for owner)
            HStack {
                if editingBandName {
                    TextField("Band Name", text: $editBandNameValue)
                        .textFieldStyle(.roundedBorder)

                    Button("Save") {
                        Task { await saveBandName() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Cancel") {
                        editingBandName = false
                    }
                    .controlSize(.small)
                } else {
                    Text(band.name)
                        .font(.title2.weight(.bold))

                    Spacer()

                    if band.isOwner {
                        Button("Edit") {
                            editBandNameValue = band.name
                            editingBandName = true
                        }
                        .font(.subheadline)

                        Button("Delete", role: .destructive) {
                            bandToDelete = band
                        }
                        .font(.subheadline)
                    }
                }
            }
            .padding(.horizontal)

            if let description = band.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            // Members
            Text("Members")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)

            if let members = band.members {
                ForEach(members) { member in
                    memberRow(member, band: band)
                }
            }

            // Invite form (owner only)
            if band.isOwner {
                Divider()
                    .padding(.vertical, 8)

                Text("Invite a Member")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal)

                HStack {
                    TextField("@handle", text: $inviteHandle)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .accessibilityIdentifier("sessionsInviteHandleField")

                    Button("Send") {
                        Task { await inviteMember() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inviteHandle.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("sessionsInviteSendButton")
                }
                .padding(.horizontal)

                if let message = inviteMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal)
                }

                if let error = inviteError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
    }

    private func memberRow(_ member: BandMember, band: Band) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("@\(member.handle)")
                        .font(.body.weight(.semibold))

                    if let firstName = member.firstName, !firstName.isEmpty {
                        Text(member.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Text(member.role.capitalized)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(member.isOwner ? Color.purple : Color(.tertiarySystemFill))
                        .foregroundStyle(member.isOwner ? .white : .secondary)
                        .clipShape(Capsule())

                    if member.status == "invited" {
                        Text("Invited")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.clear)
                            .overlay(Capsule().stroke(Color.secondary, lineWidth: 1))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if band.isOwner && !member.isOwner {
                Button("Remove") {
                    Task { await removeMember(member, from: band) }
                }
                .font(.caption)
                .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    // MARK: - Sheets

    private var saveRecordingSheet: some View {
        NavigationStack {
            SaveRecordingView(
                context: recordingContext,
                bands: activeBands,
                instruments: instruments,
                onSave: { name, date, bandId, instrumentId in
                    showSaveSheet = false
                    Task { await saveRecording(name: name, recordedAt: date, bandId: bandId, instrumentId: instrumentId) }
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

    private var ratingPopupSheet: some View {
        NavigationStack {
            RatingPopupView(
                currentRating: getCurrentRating(),
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

    private func getCurrentRating() -> Int? {
        guard let sessionId = ratingSessionId else { return nil }
        if ratingSessionSource == "bandMember" {
            return bandMemberSessions.first { $0.id == sessionId }?.myRating
        }
        return sessions.first { $0.id == sessionId }?.myRating
    }

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

    private func loadAllData() async {
        isLoading = true
        defer { isLoading = false }

        async let sessionsTask: () = loadSessions()
        async let bandMemberTask: () = loadBandMemberSessions()
        async let bandsTask: () = loadBands()
        async let instrumentsTask: () = loadInstruments()
        async let audioDefaultsTask: () = loadAudioDefaults()
        async let deviceTask: () = registerDevice()
        async let subscriptionTask: () = checkSubscriptionStatus()

        _ = await (sessionsTask, bandMemberTask, bandsTask, instrumentsTask, audioDefaultsTask, deviceTask, subscriptionTask)
    }

    private func checkSubscriptionStatus() async {
        // Check local entitlements first for quick UI update
        await storeKitManager.checkLocalEntitlements()
        // Then verify with backend
        await storeKitManager.checkSubscriptionStatus()
    }

    private func loadAudioDefaults() async {
        do {
            audioDefaults = try await SessionsAPIService.getAudioDefaults()
        } catch {
            // Non-critical - use defaults
        }
    }

    private func saveAudioDefaults() async {
        do {
            try await SessionsAPIService.saveAudioDefaults(audioDefaults)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Device Methods

    private static let deviceTokenKey = "breakroom_device_token"

    private func getDeviceToken() -> String {
        if let existing = UserDefaults.standard.string(forKey: Self.deviceTokenKey) {
            return existing
        }
        let newToken = UUID().uuidString
        UserDefaults.standard.set(newToken, forKey: Self.deviceTokenKey)
        return newToken
    }

    private func buildSystemName() -> String {
        let device = UIDevice.current
        let modelName = device.model // "iPhone", "iPad", etc.
        let systemVersion = device.systemVersion
        return "\(modelName) · iOS \(systemVersion)"
    }

    private func isEmulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private func registerDevice() async {
        do {
            let deviceToken = getDeviceToken()
            let systemName = buildSystemName()
            let device = UIDevice.current

            let deviceInfo: [String: String] = [
                "model": device.model,
                "name": device.name,
                "systemName": device.systemName,
                "systemVersion": device.systemVersion,
                "identifierForVendor": device.identifierForVendor?.uuidString ?? "unknown"
            ]

            currentDevice = try await SessionsAPIService.registerDevice(
                deviceToken: deviceToken,
                systemName: systemName,
                platform: "ios",
                isEmulator: isEmulator(),
                deviceInfo: deviceInfo
            )
        } catch {
            // Non-critical - device registration can fail silently
        }
    }

    private func startRenameDevice() {
        deviceNameInput = currentDevice?.userName ?? ""
        deviceEditing = true
    }

    private func cancelRenameDevice() {
        deviceEditing = false
        deviceNameInput = ""
    }

    private func saveDeviceName() async {
        guard let device = currentDevice else { return }
        deviceNameSaving = true
        defer { deviceNameSaving = false }

        let trimmedName = deviceNameInput.trimmingCharacters(in: .whitespaces)
        let userName: String? = trimmedName.isEmpty ? nil : trimmedName

        do {
            try await SessionsAPIService.saveDeviceName(deviceToken: device.deviceToken, userName: userName)
            currentDevice = UserDevice(
                deviceToken: device.deviceToken,
                systemName: device.systemName,
                userName: userName,
                platform: device.platform,
                isEmulator: device.isEmulator
            )
            deviceEditing = false
            deviceNameInput = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadSessions() async {
        do {
            sessions = try await SessionsAPIService.getSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadBandMemberSessions() async {
        do {
            bandMemberSessions = try await SessionsAPIService.getBandMemberSessions()
        } catch {
            // Non-critical - might fail if not in any bands
        }
    }

    private func loadBands() async {
        do {
            bands = try await SessionsAPIService.getBands()
        } catch {
            // Non-critical
        }
    }

    private func loadInstruments() async {
        do {
            instruments = try await SessionsAPIService.getInstruments()
        } catch {
            // Non-critical
        }
    }

    private func loadBandDetail(_ bandId: Int) async {
        isLoadingBand = true
        defer { isLoadingBand = false }

        do {
            activeBand = try await SessionsAPIService.getBand(bandId: bandId)
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

    private func updateSessionBand(_ session: Session, bandId: Int?) async {
        do {
            let updated = try await SessionsAPIService.updateSession(
                sessionId: session.id,
                bandId: bandId
            )
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateSessionInstrument(_ session: Session, instrumentId: Int?) async {
        do {
            let updated = try await SessionsAPIService.updateSession(
                sessionId: session.id,
                instrumentId: instrumentId
            )
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitRating(sessionId: Int, rating: Int?) async {
        do {
            let response = try await SessionsAPIService.rateSession(sessionId: sessionId, rating: rating)

            // Update in own sessions
            if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
                let old = sessions[index]
                sessions[index] = Session(
                    id: old.id, name: old.name, s3Key: old.s3Key, fileSize: old.fileSize,
                    mimeType: old.mimeType, uploadedAt: old.uploadedAt, recordedAt: old.recordedAt,
                    sessionType: old.sessionType, bandId: old.bandId, bandName: old.bandName,
                    instrumentId: old.instrumentId, instrumentName: old.instrumentName,
                    uploaderHandle: old.uploaderHandle, avgRating: response.avgRating,
                    ratingCount: response.ratingCount, myRating: response.myRating
                )
            }

            // Update in band member sessions
            if let index = bandMemberSessions.firstIndex(where: { $0.id == sessionId }) {
                let old = bandMemberSessions[index]
                bandMemberSessions[index] = Session(
                    id: old.id, name: old.name, s3Key: old.s3Key, fileSize: old.fileSize,
                    mimeType: old.mimeType, uploadedAt: old.uploadedAt, recordedAt: old.recordedAt,
                    sessionType: old.sessionType, bandId: old.bandId, bandName: old.bandName,
                    instrumentId: old.instrumentId, instrumentName: old.instrumentName,
                    uploaderHandle: old.uploaderHandle, avgRating: response.avgRating,
                    ratingCount: response.ratingCount, myRating: response.myRating
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Band API Methods

    private func createBand() async {
        let name = newBandName.trimmingCharacters(in: .whitespaces)
        let description = newBandDescription.trimmingCharacters(in: .whitespaces)

        do {
            let band = try await SessionsAPIService.createBand(
                name: name,
                description: description.isEmpty ? nil : description
            )
            bands.append(Band(
                id: band.id, name: band.name, description: band.description,
                createdBy: band.createdBy, createdAt: band.createdAt,
                role: "owner", status: "active", memberCount: 1,
                members: nil, myRole: "owner"
            ))
            activeBand = band
            showCreateBand = false
            newBandName = ""
            newBandDescription = ""
        } catch APIError.subscriptionRequired {
            // Show paywall when free limit is reached
            showPaywall = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveBandName() async {
        guard let band = activeBand else { return }
        let name = editBandNameValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, name != band.name else {
            editingBandName = false
            return
        }

        do {
            let updated = try await SessionsAPIService.updateBand(bandId: band.id, name: name, description: nil)
            activeBand = Band(
                id: updated.id, name: updated.name, description: updated.description ?? band.description,
                createdBy: band.createdBy, createdAt: band.createdAt,
                role: band.role, status: band.status, memberCount: band.memberCount,
                members: band.members, myRole: band.myRole
            )
            if let index = bands.firstIndex(where: { $0.id == band.id }) {
                bands[index] = Band(
                    id: updated.id, name: updated.name, description: bands[index].description,
                    createdBy: bands[index].createdBy, createdAt: bands[index].createdAt,
                    role: bands[index].role, status: bands[index].status, memberCount: bands[index].memberCount,
                    members: nil, myRole: bands[index].myRole
                )
            }
            editingBandName = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteBand(_ band: Band) async {
        do {
            try await SessionsAPIService.deleteBand(bandId: band.id)
            bands.removeAll { $0.id == band.id }
            if activeBand?.id == band.id {
                activeBand = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func respondToInvite(_ band: Band, action: String) async {
        do {
            try await SessionsAPIService.respondToInvite(bandId: band.id, action: action)
            if action == "accept" {
                if let index = bands.firstIndex(where: { $0.id == band.id }) {
                    bands[index] = Band(
                        id: band.id, name: band.name, description: band.description,
                        createdBy: band.createdBy, createdAt: band.createdAt,
                        role: band.role, status: "active", memberCount: (band.memberCount ?? 0) + 1,
                        members: nil, myRole: band.myRole
                    )
                }
            } else {
                bands.removeAll { $0.id == band.id }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func inviteMember() async {
        guard let band = activeBand else { return }
        let handle = inviteHandle.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "")
        guard !handle.isEmpty else { return }

        inviteMessage = nil
        inviteError = nil

        do {
            let message = try await SessionsAPIService.inviteMember(bandId: band.id, handle: handle)
            inviteMessage = message
            inviteHandle = ""
        } catch {
            inviteError = error.localizedDescription
        }
    }

    private func removeMember(_ member: BandMember, from band: Band) async {
        do {
            try await SessionsAPIService.removeMember(bandId: band.id, userId: member.id)
            if let updatedBand = activeBand, var members = updatedBand.members {
                members.removeAll { $0.id == member.id }
                activeBand = Band(
                    id: updatedBand.id, name: updatedBand.name, description: updatedBand.description,
                    createdBy: updatedBand.createdBy, createdAt: updatedBand.createdAt,
                    role: updatedBand.role, status: updatedBand.status,
                    memberCount: max(0, (updatedBand.memberCount ?? 1) - 1),
                    members: members, myRole: updatedBand.myRole
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Recording Methods

    private func startRecording() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            errorMessage = "Microphone permission is required to record sessions"
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)

            let tempDir = FileManager.default.temporaryDirectory
            let filename = "session_\(Date().timeIntervalSince1970).m4a"
            let fileURL = tempDir.appendingPathComponent(filename)

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

        recordingState = .saving
        showSaveSheet = true
    }

    private func saveRecording(name: String, recordedAt: String?, bandId: Int?, instrumentId: Int?) async {
        guard let fileURL = pendingRecordingURL else {
            recordingState = .idle
            return
        }

        do {
            let audioData = try Data(contentsOf: fileURL)
            let filename = fileURL.lastPathComponent

            let sessionType = recordingContext == "individual" ? "individual" : "band"

            let session = try await SessionsAPIService.uploadSession(
                audioData: audioData,
                filename: filename,
                name: name,
                recordedAt: recordedAt,
                bandId: bandId,
                sessionType: sessionType,
                instrumentId: instrumentId
            )

            sessions.insert(session, at: 0)

            try? FileManager.default.removeItem(at: fileURL)
            pendingRecordingURL = nil
        } catch APIError.subscriptionRequired {
            // Show paywall when free limit is reached
            // Keep the recording file so user can retry after subscribing
            showPaywall = true
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
        if nowPlayingId == session.id {
            stopPlayback()
            return
        }

        stopPlayback()

        nowPlayingId = session.id
        nowPlayingName = session.name
        nowPlayingURL = nil

        Task {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)

                guard let streamURL = SessionsAPIService.buildStreamURL(sessionId: session.id) else {
                    throw NSError(domain: "SessionsView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid stream URL"])
                }
                nowPlayingURL = streamURL

                // Create AVURLAsset with Authorization header
                var headers: [String: String] = [:]
                if let bearerToken = KeychainManager.bearerToken {
                    headers["Authorization"] = bearerToken
                }
                let asset = AVURLAsset(url: streamURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                let playerItem = AVPlayerItem(asset: asset)

                audioPlayer = AVPlayer(playerItem: playerItem)
                audioPlayer?.volume = Float(audioDefaults.playbackVolume)
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

    private func openRatingPopup(_ session: Session, source: String) {
        ratingSessionId = session.id
        ratingSessionSource = source
        showRatingPopup = true
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func groupSessions(_ sessions: [Session]) -> [(year: Int, months: [(month: Int, sessions: [Session])])] {
        let byYear = Dictionary(grouping: sessions) { $0.year }
        return byYear.keys.sorted(by: >).map { year in
            let yearSessions = byYear[year]!
            let byMonth = Dictionary(grouping: yearSessions) { $0.month }
            let months = byMonth.keys.sorted(by: >).map { month in
                (month: month, sessions: byMonth[month]!.sorted { ($0.recordedAt ?? $0.uploadedAt) > ($1.recordedAt ?? $1.uploadedAt) })
            }
            return (year: year, months: months)
        }
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let session: Session
    let isPlaying: Bool
    let bands: [Band]
    let instruments: [Instrument]
    let showBandPicker: Bool
    let showInstrumentPicker: Bool
    let onPlay: () -> Void
    let onRate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onBandChange: (Int?) -> Void
    let onInstrumentChange: (Int?) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(isPlaying ? .red : .purple)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sessionsPlayButton_\(session.id)")

            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.body)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onEdit)

                Text(session.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if showBandPicker || showInstrumentPicker {
                    HStack(spacing: 8) {
                        if showBandPicker {
                            Menu {
                                Button("No band") { onBandChange(nil) }
                                ForEach(bands) { band in
                                    Button(band.name) { onBandChange(band.id) }
                                }
                            } label: {
                                Text(session.bandName ?? "No band")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.tertiarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }

                        if showInstrumentPicker {
                            Menu {
                                Button("No instrument") { onInstrumentChange(nil) }
                                ForEach(instruments) { instrument in
                                    Button(instrument.name) { onInstrumentChange(instrument.id) }
                                }
                            } label: {
                                Text(session.instrumentName ?? "No instrument")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.tertiarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }
            }

            Spacer()

            if !session.formattedFileSize.isEmpty {
                Text(session.formattedFileSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            RatingChip(
                avgRating: session.avgRating,
                ratingCount: session.ratingCount,
                myRating: session.myRating,
                onTap: onRate
            )

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sessionsDeleteButton_\(session.id)")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .accessibilityIdentifier("sessionsRow_\(session.id)")
    }
}

// MARK: - Band Member Session Row

private struct BandMemberSessionRow: View {
    let session: Session
    let isPlaying: Bool
    let onPlay: () -> Void
    let onRate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(isPlaying ? .red : .purple)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sessionsBandMemberPlayButton_\(session.id)")

            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.body)
                    .lineLimit(1)

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
            }

            Spacer()

            Text(session.formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !session.formattedFileSize.isEmpty {
                Text(session.formattedFileSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            RatingChip(
                avgRating: session.avgRating,
                ratingCount: session.ratingCount,
                myRating: session.myRating,
                onTap: onRate
            )
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
                .background(myRating != nil ? Color.purple.opacity(0.2) : Color(.tertiarySystemFill))
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
    let context: String
    let bands: [Band]
    let instruments: [Instrument]
    let onSave: (String, String?, Int?, Int?) -> Void
    let onDiscard: () -> Void

    @State private var name: String
    @State private var date: String
    @State private var selectedBandId: Int?
    @State private var selectedInstrumentId: Int?

    init(context: String, bands: [Band], instruments: [Instrument], onSave: @escaping (String, String?, Int?, Int?) -> Void, onDiscard: @escaping () -> Void) {
        self.context = context
        self.bands = bands
        self.instruments = instruments
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
                    .accessibilityIdentifier("sessionsSessionNameField")
                TextField("Date (YYYY-MM-DD)", text: $date)
                    .accessibilityIdentifier("sessionsSessionDateField")
            }

            Section {
                Picker("Band", selection: $selectedBandId) {
                    Text("No band").tag(nil as Int?)
                    ForEach(bands) { band in
                        Text(band.name).tag(band.id as Int?)
                    }
                }
                .accessibilityIdentifier("sessionsSessionBandPicker")

                if context == "individual" {
                    Picker("Instrument", selection: $selectedInstrumentId) {
                        Text("No instrument").tag(nil as Int?)
                        ForEach(instruments) { instrument in
                            Text(instrument.name).tag(instrument.id as Int?)
                        }
                    }
                    .accessibilityIdentifier("sessionsSessionInstrumentPicker")
                }
            }
        }
        .accessibilityIdentifier("sessionsSaveRecordingForm")
        .navigationTitle("Save Recording")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Discard", role: .destructive, action: onDiscard)
                    .accessibilityIdentifier("sessionsDiscardButton")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(name, date.isEmpty ? nil : date, selectedBandId, selectedInstrumentId)
                }
                .disabled(name.isEmpty)
                .accessibilityIdentifier("sessionsSaveRecordingButton")
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

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { n in
                    ratingButton(n)
                }
            }

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
                .background(currentRating == value ? Color.purple : Color(.tertiarySystemFill))
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

// MARK: - Audio Defaults Sheet

private struct AudioDefaultsSheet: View {
    @Binding var defaults: AudioDefaults
    let currentDevice: UserDevice?
    @Binding var deviceEditing: Bool
    @Binding var deviceNameInput: String
    let deviceNameSaving: Bool
    let onSave: () -> Void
    let onStartRename: () -> Void
    let onCancelRename: () -> Void
    let onSaveDeviceName: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Device section
                if let device = currentDevice {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("This Device")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button(deviceEditing ? "Cancel" : "Rename") {
                                    if deviceEditing {
                                        onCancelRename()
                                    } else {
                                        onStartRename()
                                    }
                                }
                                .font(.caption)
                            }

                            if !deviceEditing {
                                Text(device.userName ?? device.systemName)
                                    .font(.body.weight(.semibold))
                            } else {
                                HStack(spacing: 8) {
                                    TextField(device.systemName, text: $deviceNameInput)
                                        .textFieldStyle(.roundedBorder)

                                    Button {
                                        onSaveDeviceName()
                                    } label: {
                                        if deviceNameSaving {
                                            ProgressView()
                                                .frame(width: 14, height: 14)
                                        } else {
                                            Text("Save")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(deviceNameSaving)
                                }
                            }
                        }
                    }
                }

                Section {
                    Toggle("Echo Cancellation", isOn: $defaults.echoCancellation)
                    Toggle("Noise Suppression", isOn: $defaults.noiseSuppression)
                    Toggle("Auto Gain Control", isOn: $defaults.autoGainControl)
                } header: {
                    Text("Recording Settings")
                } footer: {
                    Text("These settings are applied when recording audio.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Playback Volume")
                            Spacer()
                            Text("\(Int(defaults.playbackVolume * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $defaults.playbackVolume, in: 0...1, step: 0.05)
                    }
                } header: {
                    Text("Playback Settings")
                }
            }
            .navigationTitle("Audio Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NavigationStack {
        SessionsView()
    }
}
