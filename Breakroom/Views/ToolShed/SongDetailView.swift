import SwiftUI

struct SongDetailView: View {
    let songId: Int
    let onUpdate: (Song) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var song: Song?
    @State private var lyrics: [Lyric] = []
    @State private var collaborators: [SongCollaborator] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false

    // Sheets
    @State private var showEditSongSheet = false
    @State private var showAddLyricSheet = false
    @State private var editingLyric: Lyric?

    // Delete confirmation
    @State private var lyricToDelete: Lyric?
    @State private var showDeleteLyricConfirm = false

    private var canEdit: Bool {
        guard let song else { return false }
        if !song.isCollaboration { return true }
        return song.collaboratorRole == .editor
    }

    private var groupedLyrics: [(LyricSectionType, [Lyric])] {
        let grouped = Dictionary(grouping: lyrics) { $0.lyricSectionType }
        let order: [LyricSectionType] = [.intro, .verse, .preChorus, .chorus, .bridge, .hook, .outro, .idea, .other]
        return order.compactMap { type in
            guard let items = grouped[type], !items.isEmpty else { return nil }
            let sorted = items.sorted { ($0.sectionOrder ?? 0) < ($1.sectionOrder ?? 0) }
            return (type, sorted)
        }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let song {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Song header
                        songHeader(song)

                        // Collaborators section
                        if !collaborators.isEmpty {
                            collaboratorsSection
                        }

                        // Lyrics section
                        lyricsSection
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(song?.title ?? "Song")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if canEdit {
                    Menu {
                        Button {
                            showAddLyricSheet = true
                        } label: {
                            Label("Add Lyric", systemImage: "text.badge.plus")
                        }
                        Button {
                            showEditSongSheet = true
                        } label: {
                            Label("Edit Song", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await loadSong()
        }
        .refreshable {
            await loadSong()
        }
        .sheet(isPresented: $showEditSongSheet) {
            if let song {
                EditSongSheet(song: song) { updated in
                    self.song = updated
                    onUpdate(updated)
                }
            }
        }
        .sheet(isPresented: $showAddLyricSheet) {
            AddLyricSheet(songId: songId) { newLyric in
                lyrics.append(newLyric)
            }
        }
        .sheet(item: $editingLyric) { lyric in
            EditLyricSheet(lyric: lyric, songId: songId) { updated in
                if let idx = lyrics.firstIndex(where: { $0.id == updated.id }) {
                    lyrics[idx] = updated
                }
            }
        }
        .alert("Delete Lyric", isPresented: $showDeleteLyricConfirm) {
            Button("Delete", role: .destructive) {
                if let lyric = lyricToDelete {
                    Task { await deleteLyric(lyric) }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Delete this lyric section?")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    // MARK: - Song Header

    private func songHeader(_ song: Song) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(song.title)
                    .font(.title2.bold())
                Spacer()
                statusBadge(song.songStatus)
            }

            HStack(spacing: 12) {
                if let genre = song.genre, !genre.isEmpty {
                    Label(genre, systemImage: "music.note")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let role = song.collaboratorRole {
                    Text(role.displayName)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                visibilityBadge(song.songVisibility)
            }

            if let description = song.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statusBadge(_ status: SongStatus) -> some View {
        let color: Color = switch status {
        case .idea: .gray
        case .writing: .blue
        case .complete: .green
        case .recorded: .purple
        case .released: .orange
        }

        return Text(status.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func visibilityBadge(_ visibility: SongVisibility) -> some View {
        let icon: String = switch visibility {
        case .private: "lock"
        case .collaborators: "person.2"
        case .public: "globe"
        }

        return Label(visibility.displayName, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Collaborators Section

    private var collaboratorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Collaborators")
                .font(.headline)

            ForEach(collaborators) { collab in
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text(collab.displayName)
                            .font(.subheadline)
                        Text(collab.collaboratorRole.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Lyrics Section

    private var lyricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Lyrics")
                    .font(.headline)
                Spacer()
                Text("\(lyrics.count) section\(lyrics.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if lyrics.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.quote")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No lyrics yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if canEdit {
                        Button("Add Lyric") {
                            showAddLyricSheet = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(groupedLyrics, id: \.0) { sectionType, sectionLyrics in
                    lyricGroupSection(sectionType, lyrics: sectionLyrics)
                }
            }
        }
    }

    private func lyricGroupSection(_ sectionType: LyricSectionType, lyrics: [Lyric]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sectionType.displayName.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            ForEach(lyrics) { lyric in
                lyricCard(lyric)
            }
        }
    }

    private func lyricCard(_ lyric: Lyric) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lyric.content)
                .font(.body)

            HStack {
                if let mood = lyric.mood, !mood.isEmpty {
                    Label(mood, systemImage: "face.smiling")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                }

                if let order = lyric.sectionOrder {
                    Text("#\(order)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if canEdit {
                    Button {
                        editingLyric = lyric
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Button {
                        lyricToDelete = lyric
                        showDeleteLyricConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red.opacity(0.7))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    // MARK: - Data Loading

    private func loadSong() async {
        do {
            let response = try await LyricAPIService.getSong(id: songId)
            song = response.song
            lyrics = response.lyrics
            collaborators = response.collaborators
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }

    private func deleteLyric(_ lyric: Lyric) async {
        do {
            try await LyricAPIService.deleteLyric(id: lyric.id)
            lyrics.removeAll { $0.id == lyric.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Edit Song Sheet

struct EditSongSheet: View {
    let song: Song
    let onSave: (Song) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var genre: String
    @State private var status: SongStatus
    @State private var visibility: SongVisibility
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    init(song: Song, onSave: @escaping (Song) -> Void) {
        self.song = song
        self.onSave = onSave
        _title = State(initialValue: song.title)
        _description = State(initialValue: song.description ?? "")
        _genre = State(initialValue: song.genre ?? "")
        _status = State(initialValue: song.songStatus)
        _visibility = State(initialValue: song.songVisibility)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Song Info") {
                    TextField("Title *", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Genre", text: $genre)
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(SongStatus.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                }

                Section("Visibility") {
                    Picker("Visibility", selection: $visibility) {
                        ForEach(SongVisibility.allCases, id: \.self) { v in
                            Text(v.displayName).tag(v)
                        }
                    }
                }
            }
            .navigationTitle("Edit Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private func save() async {
        isSaving = true
        let desc = description.trimmingCharacters(in: .whitespaces)
        let g = genre.trimmingCharacters(in: .whitespaces)

        do {
            let updated = try await LyricAPIService.updateSong(
                id: song.id,
                title: title.trimmingCharacters(in: .whitespaces),
                description: desc.isEmpty ? nil : desc,
                genre: g.isEmpty ? nil : g,
                status: status.rawValue,
                visibility: visibility.rawValue
            )
            onSave(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}

// MARK: - Add Lyric Sheet

struct AddLyricSheet: View {
    let songId: Int
    let onSave: (Lyric) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var content = ""
    @State private var sectionType: LyricSectionType = .verse
    @State private var sectionOrder: String = ""
    @State private var mood = ""
    @State private var notes = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Lyric Content") {
                    TextField("Write your lyrics...", text: $content, axis: .vertical)
                        .lineLimit(5...15)
                }

                Section("Section") {
                    Picker("Type", selection: $sectionType) {
                        ForEach(LyricSectionType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    TextField("Order (e.g., 1, 2, 3)", text: $sectionOrder)
                        .keyboardType(.numberPad)
                }

                Section("Optional") {
                    TextField("Mood", text: $mood)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Add Lyric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private func save() async {
        isSaving = true
        let m = mood.trimmingCharacters(in: .whitespaces)
        let n = notes.trimmingCharacters(in: .whitespaces)
        let order = Int(sectionOrder)

        do {
            let lyric = try await LyricAPIService.createLyric(
                songId: songId,
                title: nil,
                content: content.trimmingCharacters(in: .whitespaces),
                sectionType: sectionType.rawValue,
                sectionOrder: order,
                mood: m.isEmpty ? nil : m,
                notes: n.isEmpty ? nil : n,
                status: "draft"
            )
            onSave(lyric)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}

// MARK: - Edit Lyric Sheet

struct EditLyricSheet: View {
    let lyric: Lyric
    let songId: Int
    let onSave: (Lyric) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var content: String
    @State private var sectionType: LyricSectionType
    @State private var sectionOrder: String
    @State private var mood: String
    @State private var notes: String
    @State private var status: LyricStatus
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    init(lyric: Lyric, songId: Int, onSave: @escaping (Lyric) -> Void) {
        self.lyric = lyric
        self.songId = songId
        self.onSave = onSave
        _content = State(initialValue: lyric.content)
        _sectionType = State(initialValue: lyric.lyricSectionType)
        _sectionOrder = State(initialValue: lyric.sectionOrder.map { String($0) } ?? "")
        _mood = State(initialValue: lyric.mood ?? "")
        _notes = State(initialValue: lyric.notes ?? "")
        _status = State(initialValue: lyric.lyricStatus)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Lyric Content") {
                    TextField("Write your lyrics...", text: $content, axis: .vertical)
                        .lineLimit(5...15)
                }

                Section("Section") {
                    Picker("Type", selection: $sectionType) {
                        ForEach(LyricSectionType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    TextField("Order (e.g., 1, 2, 3)", text: $sectionOrder)
                        .keyboardType(.numberPad)
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(LyricStatus.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                }

                Section("Optional") {
                    TextField("Mood", text: $mood)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Edit Lyric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private func save() async {
        isSaving = true
        let m = mood.trimmingCharacters(in: .whitespaces)
        let n = notes.trimmingCharacters(in: .whitespaces)
        let order = Int(sectionOrder)

        do {
            let updated = try await LyricAPIService.updateLyric(
                id: lyric.id,
                songId: songId,
                title: nil,
                content: content.trimmingCharacters(in: .whitespaces),
                sectionType: sectionType.rawValue,
                sectionOrder: order,
                mood: m.isEmpty ? nil : m,
                notes: n.isEmpty ? nil : n,
                status: status.rawValue
            )
            onSave(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}
