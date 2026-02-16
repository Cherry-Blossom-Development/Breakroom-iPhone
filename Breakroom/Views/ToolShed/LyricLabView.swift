import SwiftUI

struct LyricLabView: View {
    enum Tab: String, CaseIterable {
        case songs = "Songs"
        case ideas = "Ideas"
    }

    @State private var selectedTab: Tab = .songs
    @State private var songs: [Song] = []
    @State private var ideas: [Lyric] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false

    // Sheets
    @State private var showNewSongSheet = false
    @State private var showQuickIdeaSheet = false
    @State private var selectedSong: Song?

    // Delete confirmations
    @State private var songToDelete: Song?
    @State private var showDeleteSongConfirm = false
    @State private var ideaToDelete: Lyric?
    @State private var showDeleteIdeaConfirm = false

    // Edit
    @State private var editingIdea: Lyric?
    @State private var editingSong: Song?

    private var mySongs: [Song] {
        songs.filter { !$0.isCollaboration }
    }

    private var collaborations: [Song] {
        songs.filter { $0.isCollaboration }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Content
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxHeight: .infinity)
                } else {
                    switch selectedTab {
                    case .songs:
                        songsTab
                    case .ideas:
                        ideasTab
                    }
                }
            }
        }
        .navigationTitle("Lyric Lab")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showQuickIdeaSheet = true
                    } label: {
                        Label("Quick Idea", systemImage: "lightbulb")
                    }
                    Button {
                        showNewSongSheet = true
                    } label: {
                        Label("New Song", systemImage: "music.note.list")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .sheet(isPresented: $showNewSongSheet) {
            NewSongSheet { newSong in
                songs.insert(newSong, at: 0)
            }
        }
        .sheet(isPresented: $showQuickIdeaSheet) {
            QuickIdeaSheet { newIdea in
                ideas.insert(newIdea, at: 0)
            }
        }
        .sheet(item: $selectedSong) { song in
            NavigationStack {
                SongDetailView(songId: song.id) { updatedSong in
                    if let idx = songs.firstIndex(where: { $0.id == updatedSong.id }) {
                        songs[idx] = updatedSong
                    }
                } onDelete: {
                    songs.removeAll { $0.id == song.id }
                }
            }
        }
        .sheet(item: $editingIdea) { idea in
            EditIdeaSheet(idea: idea) { updatedIdea in
                if let idx = ideas.firstIndex(where: { $0.id == updatedIdea.id }) {
                    ideas[idx] = updatedIdea
                }
            }
        }
        .sheet(item: $editingSong) { song in
            EditSongSheet(song: song) { updatedSong in
                if let idx = songs.firstIndex(where: { $0.id == updatedSong.id }) {
                    songs[idx] = updatedSong
                }
            }
        }
        .alert("Delete Song", isPresented: $showDeleteSongConfirm) {
            Button("Delete", role: .destructive) {
                if let song = songToDelete {
                    Task { await deleteSong(song) }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let song = songToDelete {
                Text("Delete \"\(song.title)\" and all its lyrics?")
            }
        }
        .alert("Delete Idea", isPresented: $showDeleteIdeaConfirm) {
            Button("Delete", role: .destructive) {
                if let idea = ideaToDelete {
                    Task { await deleteIdea(idea) }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Delete this lyric idea?")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    // MARK: - Songs Tab

    private var songsTab: some View {
        Group {
            if mySongs.isEmpty && collaborations.isEmpty {
                ContentUnavailableView(
                    "No Songs Yet",
                    systemImage: "music.note.list",
                    description: Text("Create your first song to start organizing your lyrics.")
                )
            } else {
                List {
                    if !mySongs.isEmpty {
                        Section("My Songs") {
                            ForEach(mySongs) { song in
                                songRow(song)
                            }
                        }
                    }

                    if !collaborations.isEmpty {
                        Section("Collaborations") {
                            ForEach(collaborations) { song in
                                songRow(song)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func songRow(_ song: Song) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(song.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
                statusBadge(song.songStatus)
            }

            if let description = song.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 8) {
                if let genre = song.genre, !genre.isEmpty {
                    Text(genre)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                if let role = song.collaboratorRole {
                    Text(role.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Spacer()

                if let count = song.lyricCount, count > 0 {
                    Label("\(count) lyric\(count == 1 ? "" : "s")", systemImage: "text.quote")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            editingSong = song
        }
        .contextMenu {
            Button {
                editingSong = song
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button {
                selectedSong = song
            } label: {
                Label("View Lyrics", systemImage: "text.quote")
            }
            Divider()
            Button(role: .destructive) {
                songToDelete = song
                showDeleteSongConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
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
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Ideas Tab

    private var ideasTab: some View {
        Group {
            if ideas.isEmpty {
                ContentUnavailableView(
                    "No Ideas Yet",
                    systemImage: "lightbulb",
                    description: Text("Capture quick lyric ideas that you can later organize into songs.")
                )
            } else {
                List {
                    ForEach(ideas) { idea in
                        ideaRow(idea)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func ideaRow(_ idea: Lyric) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(idea.contentPreview)
                .font(.body)
                .lineLimit(3)

            HStack(spacing: 8) {
                if let mood = idea.mood, !mood.isEmpty {
                    Label(mood, systemImage: "face.smiling")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .foregroundStyle(.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                lyricStatusBadge(idea.lyricStatus)

                Spacer()

                if let date = idea.createdAt {
                    Text(formatDate(date))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            editingIdea = idea
        }
        .contextMenu {
            Button {
                editingIdea = idea
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                ideaToDelete = idea
                showDeleteIdeaConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func lyricStatusBadge(_ status: LyricStatus) -> some View {
        let color: Color = switch status {
        case .draft: .gray
        case .inProgress: .blue
        case .complete: .green
        case .archived: .secondary
        }

        return Text(status.displayName)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Data Loading

    private func loadData() async {
        do {
            async let songsResult = LyricAPIService.getSongs()
            async let ideasResult = LyricAPIService.getStandaloneLyrics()

            songs = try await songsResult
            ideas = try await ideasResult
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }

    private func deleteSong(_ song: Song) async {
        do {
            try await LyricAPIService.deleteSong(id: song.id)
            songs.removeAll { $0.id == song.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deleteIdea(_ idea: Lyric) async {
        do {
            try await LyricAPIService.deleteLyric(id: idea.id)
            ideas.removeAll { $0.id == idea.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func formatDate(_ dateString: String) -> String {
        // Simple date formatting - just show the date part
        String(dateString.prefix(10))
    }
}

// MARK: - New Song Sheet

struct NewSongSheet: View {
    let onSave: (Song) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var genre = ""
    @State private var status: SongStatus = .idea
    @State private var visibility: SongVisibility = .private
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Song Info") {
                    TextField("Title *", text: $title)
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("Description")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
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
            .navigationTitle("New Song")
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
                            Text("Create")
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
            let song = try await LyricAPIService.createSong(
                title: title.trimmingCharacters(in: .whitespaces),
                description: desc.isEmpty ? nil : desc,
                genre: g.isEmpty ? nil : g,
                status: status.rawValue,
                visibility: visibility.rawValue
            )
            onSave(song)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}

// MARK: - Quick Idea Sheet

struct QuickIdeaSheet: View {
    let onSave: (Lyric) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var content = ""
    @State private var mood = ""
    @State private var notes = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Lyric") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                        .overlay(alignment: .topLeading) {
                            if content.isEmpty {
                                Text("Write your lyric idea...")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section("Optional") {
                    TextField("Mood (e.g., happy, melancholy)", text: $mood)
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                        .overlay(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("Notes")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }
            .navigationTitle("Quick Idea")
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

        do {
            let lyric = try await LyricAPIService.createLyric(
                songId: nil,
                title: nil,
                content: content.trimmingCharacters(in: .whitespaces),
                sectionType: "idea",
                sectionOrder: nil,
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

// MARK: - Edit Idea Sheet

struct EditIdeaSheet: View {
    let idea: Lyric
    let onSave: (Lyric) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var content: String
    @State private var mood: String
    @State private var notes: String
    @State private var status: LyricStatus
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    init(idea: Lyric, onSave: @escaping (Lyric) -> Void) {
        self.idea = idea
        self.onSave = onSave
        _title = State(initialValue: idea.title ?? "")
        _content = State(initialValue: idea.content)
        _mood = State(initialValue: idea.mood ?? "")
        _notes = State(initialValue: idea.notes ?? "")
        _status = State(initialValue: idea.lyricStatus)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Idea") {
                    TextField("Title (optional)", text: $title)
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                        .overlay(alignment: .topLeading) {
                            if content.isEmpty {
                                Text("Write your lyric idea...")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(LyricStatus.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                }

                Section("Optional") {
                    TextField("Mood (e.g., happy, melancholy)", text: $mood)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Edit Idea")
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
        let t = title.trimmingCharacters(in: .whitespaces)
        let m = mood.trimmingCharacters(in: .whitespaces)
        let n = notes.trimmingCharacters(in: .whitespaces)

        do {
            let updated = try await LyricAPIService.updateLyric(
                id: idea.id,
                songId: nil,
                title: t.isEmpty ? nil : t,
                content: content.trimmingCharacters(in: .whitespaces),
                sectionType: "idea",
                sectionOrder: nil,
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
