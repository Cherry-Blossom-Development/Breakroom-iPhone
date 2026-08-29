import SwiftUI

struct GamesView: View {
    @State private var isLoading = true
    @State private var error: String?
    @State private var game: HaulonautGame?
    @State private var instances: [HaulonautInstance] = []
    @State private var characters: [HaulonautCharacter] = []

    // Character creation
    @State private var showCreateSheet = false
    @State private var newCharacterName = ""
    @State private var selectedInstanceId: Int?
    @State private var isCreating = false
    @State private var createError: String?

    // Navigation to play screen
    @State private var navigateToCharacterId: Int?

    // Dynamic type support
    @ScaledMetric(relativeTo: .body) private var adPadding: CGFloat = 24
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var mostRecentCharacter: HaulonautCharacter? {
        characters.first
    }

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading games...")
                    .accessibilityIdentifier("gamesLoading")
            } else if let error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await loadGame() }
                    }
                    .accessibilityIdentifier("gamesRetryButton")
                }
                .accessibilityIdentifier("gamesError")
            } else if let game {
                gameContent(game)
            }
        }
        .accessibilityIdentifier("screenGames")
        .navigationTitle("Games")
        .navigationDestination(for: Int.self) { characterId in
            HaulonautPlayView(characterId: characterId)
        }
        .task {
            await loadGame()
        }
        .sheet(isPresented: $showCreateSheet) {
            createCharacterSheet
        }
        .onChange(of: navigateToCharacterId) { _, newValue in
            // This is handled via NavigationLink value
        }
    }

    // MARK: - Game Content

    @ViewBuilder
    private func gameContent(_ game: HaulonautGame) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Haulonaut Ad Card
                haulonautAdCard(game)

                // Active Universes
                if !instances.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Universes")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(instances) { instance in
                            universeCard(instance)
                        }
                    }
                }

                // Your Current Games
                if !characters.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Current Games")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(characters) { character in
                            characterCard(character)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .accessibilityIdentifier("gamesScrollView")
    }

    // MARK: - Haulonaut Ad Card

    private func haulonautAdCard(_ game: HaulonautGame) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Scanline overlay effect would go here with proper implementation
            Text(">>> INCOMING TRANSMISSION")
                .font(.caption.monospaced())
                .foregroundStyle(Color(red: 0.18, green: 0.84, blue: 0.43))

            Text(game.name.uppercased())
                .font(.title.bold().monospaced())
                .foregroundStyle(Color(red: 0.30, green: 1.0, blue: 0.53))

            Text("Haul cargo. Chart the void. Make your fortune — or lose everything.")
                .font(.subheadline.monospaced())
                .foregroundStyle(Color(red: 0.73, green: 1.0, blue: 0.81))

            if let description = game.description, !description.isEmpty {
                Text(description)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color(red: 0.56, green: 0.90, blue: 0.67))
            }

            Text("1000-SECTOR UNIVERSES · TEXT-BASED · PERMADEATH")
                .font(.caption2.monospaced())
                .foregroundStyle(Color(red: 0.18, green: 0.84, blue: 0.43))
                .padding(.top, 4)

            // Play button
            Button {
                handlePlayNow()
            } label: {
                Text(playButtonLabel)
                    .font(.headline.monospaced().bold())
                    .foregroundStyle(Color(red: 0.73, green: 1.0, blue: 0.81))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.12, green: 0.54, blue: 0.30))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(red: 0.30, green: 1.0, blue: 0.53), lineWidth: 2)
                    }
            }
            .disabled(!canPlay)
            .opacity(canPlay ? 1.0 : 0.5)
            .accessibilityIdentifier("gamesPlayNowButton")
            .padding(.top, 8)
        }
        .padding(adPadding)
        .background(Color(red: 0.02, green: 0.07, blue: 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(red: 0.12, green: 0.54, blue: 0.30), lineWidth: 2)
        }
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Haulonaut. \(game.description ?? "Space trading game"). \(playButtonLabel)")
    }

    private var canPlay: Bool {
        mostRecentCharacter != nil || !instances.isEmpty
    }

    private var playButtonLabel: String {
        if mostRecentCharacter != nil {
            return "RESUME ▶"
        } else if !instances.isEmpty {
            return "PLAY NOW ▶"
        } else {
            return "NO UNIVERSES ONLINE"
        }
    }

    private func handlePlayNow() {
        if let recent = mostRecentCharacter {
            navigateToCharacterId = recent.id
        } else if !instances.isEmpty {
            openCreateSheet(instanceId: nil)
        }
    }

    // MARK: - Universe Card

    private func universeCard(_ instance: HaulonautInstance) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(instance.name)
                    .font(.subheadline.weight(.semibold))

                Text("\(instance.sectorCount) sectors · \(instance.playerCount) player\(instance.playerCount == 1 ? "" : "s") · since \(formatDate(instance.startedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("+ New Character") {
                openCreateSheet(instanceId: instance.id)
            }
            .font(.caption.weight(.medium))
            .buttonStyle(.bordered)
            .accessibilityIdentifier("gamesNewCharacterButton_\(instance.id)")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    // MARK: - Character Card

    private func characterCard(_ character: HaulonautCharacter) -> some View {
        let statusColor: Color = {
            switch character.status {
            case "active": return .green
            case "dead": return .red
            default: return .secondary
            }
        }()

        let endedSuffix = (character.instanceStatus != nil && character.instanceStatus != "active") ? " (ended)" : ""
        let metaLabel = "\(character.status.capitalized) in \(character.instanceName ?? "Unknown")\(endedSuffix) · Started \(formatDate(character.createdAt)) · Last played \(formatDate(character.lastPlayedAt))"

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(character.displayName)
                    .font(.subheadline.weight(.semibold))

                Text(metaLabel)
                    .font(.caption)
                    .foregroundStyle(character.status != "active" ? statusColor : .secondary)
            }

            Spacer()

            NavigationLink(value: character.id) {
                Text("Resume")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("gamesResumeButton_\(character.id)")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(character.displayName). \(metaLabel)")
    }

    // MARK: - Create Character Sheet

    private func openCreateSheet(instanceId: Int?) {
        newCharacterName = ""
        createError = nil
        selectedInstanceId = instanceId ?? instances.first?.id
        showCreateSheet = true
    }

    private var createCharacterSheet: some View {
        NavigationStack {
            Form {
                if instances.count > 1 {
                    Section {
                        Picker("Universe", selection: $selectedInstanceId) {
                            ForEach(instances) { instance in
                                Text(instance.name).tag(instance.id as Int?)
                            }
                        }
                    }
                }

                Section {
                    TextField("Captain name", text: $newCharacterName)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("gamesCaptainNameField")
                }

                if let createError {
                    Section {
                        Text(createError)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Name Your Captain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCreateSheet = false
                    }
                    .accessibilityIdentifier("gamesCreateCancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreating ? "Launching..." : "Launch") {
                        Task { await createCharacter() }
                    }
                    .disabled(newCharacterName.trimmingCharacters(in: .whitespaces).isEmpty || selectedInstanceId == nil || isCreating)
                    .accessibilityIdentifier("gamesLaunchButton")
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func loadGame() async {
        isLoading = true
        error = nil

        do {
            let response = try await GamesAPIService.getGameInfo()
            game = response.game
            instances = response.instances
            characters = response.characters
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func createCharacter() async {
        let name = newCharacterName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let instanceId = selectedInstanceId else { return }

        isCreating = true
        createError = nil

        do {
            let character = try await GamesAPIService.createCharacter(displayName: name, instanceId: instanceId)
            showCreateSheet = false
            navigateToCharacterId = character.id
        } catch {
            createError = error.localizedDescription
        }

        isCreating = false
    }

    // MARK: - Helpers

    private func formatDate(_ dateStr: String?) -> String {
        guard let dateStr else { return "—" }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Try with fractional seconds first, then without
        var date = formatter.date(from: dateStr)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: dateStr)
        }

        guard let parsedDate = date else { return dateStr }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        return displayFormatter.string(from: parsedDate)
    }
}

#Preview {
    NavigationStack {
        GamesView()
    }
}
