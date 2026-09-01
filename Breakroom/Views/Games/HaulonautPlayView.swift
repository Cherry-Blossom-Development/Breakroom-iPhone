import SwiftUI

// MARK: - Viewport Mode

enum HaulonautViewportMode {
    case space
    case outpost
    case cargo
    case charts
}

// MARK: - CRT Colors

private enum CRTColors {
    static let background = Color(red: 0.02, green: 0.07, blue: 0.04)
    static let border = Color(red: 0.12, green: 0.54, blue: 0.30)
    static let title = Color(red: 0.30, green: 1.0, blue: 0.53)
    static let tagline = Color(red: 0.73, green: 1.0, blue: 0.81)
    static let description = Color(red: 0.56, green: 0.90, blue: 0.67)
    static let stat = Color(red: 0.18, green: 0.84, blue: 0.43)
    static let muted = Color(red: 0.37, green: 0.68, blue: 0.49)
    static let error = Color(red: 1.0, green: 0.54, blue: 0.54)
}

// MARK: - Main View

struct HaulonautPlayView: View {
    let characterId: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Dynamic type support
    @ScaledMetric(relativeTo: .body) private var planetSize: CGFloat = 72
    @ScaledMetric(relativeTo: .body) private var outpostIconSize: CGFloat = 32
    @ScaledMetric(relativeTo: .caption) private var chipPadding: CGFloat = 12

    @State private var isLoading = true
    @State private var error: String?
    @State private var character: HaulonautCharacter?
    @State private var currentSector: HaulonautSector?
    @State private var connectedSectors: [HaulonautConnectedSector] = []
    @State private var features: [HaulonautSectorFeature] = []
    @State private var playersHere: [HaulonautPlayerHere] = []
    @State private var credits: Int = 0
    @State private var rations: Int = 0
    @State private var fuel: Int = 0
    @State private var inventory: [HaulonautInventoryItem] = []
    @State private var itemsCatalog: [HaulonautItem] = []

    @State private var viewportMode: HaulonautViewportMode = .space
    @State private var isNavigating = false
    @State private var isPurchasing = false
    @State private var snackbarMessage: String?

    // Star Charts & Autopilot
    @State private var knownLocations: [HaulonautKnownLocation] = []
    @State private var traveling = false
    @State private var travelPath: [HaulonautRouteWaypoint] = []
    @State private var travelDestination: String?

    // Drift (uncontrolled movement when fuel is 0)
    @State private var driftVariance: Int = 0
    @State private var drifting = false
    @State private var driftTask: Task<Void, Never>?
    @State private var previousFuel: Int = 0

    // Computed properties
    var planetFeature: HaulonautSectorFeature? {
        features.first { $0.featureType == "planet" }
    }

    var outpostFeature: HaulonautSectorFeature? {
        features.first { $0.featureType == "trading_outpost" }
    }

    /// Ship should drift: out of fuel and not at a planet (which would stabilize).
    var driftEligible: Bool {
        fuel <= 0 && planetFeature == nil
    }

    /// Can't warp if either rations or fuel is depleted.
    var canWarp: Bool {
        rations > 0 && fuel > 0
    }

    func inventoryQuantity(for itemKey: String) -> Int {
        inventory.first { $0.itemKey == itemKey }?.quantity ?? 0
    }

    var body: some View {
        ZStack {
            // CRT background
            CRTColors.background
                .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(CRTColors.title)
                    .accessibilityIdentifier("haulonautLoading")
            } else if let error {
                errorView(error)
            } else {
                gameContent
            }

            // Snackbar overlay
            if let message = snackbarMessage {
                VStack {
                    Spacer()
                    snackbar(message)
                        .padding(.bottom, 100)
                }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: snackbarMessage)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(character?.displayName ?? "Haulonaut")
                    .font(.headline.monospaced())
                    .foregroundStyle(CRTColors.tagline)
            }
            ToolbarItem(placement: .topBarTrailing) {
                resourcesDisplay
            }
        }
        .toolbarBackground(CRTColors.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .accessibilityIdentifier("screenHaulonautPlay")
        .task {
            await loadCharacter()
        }
        .onDisappear {
            driftTask?.cancel()
            driftTask = nil
        }
    }

    // MARK: - Resources Display

    private var resourcesDisplay: some View {
        HStack(spacing: 12) {
            resourcePill(label: "Credits", value: credits)
            resourcePill(label: "Rations", value: rations)
            resourcePill(label: "Fuel", value: fuel)
            if driftEligible {
                driftVariancePill
            }
        }
    }

    private func resourcePill(label: String, value: Int) -> some View {
        let color = value <= 0 ? CRTColors.error : CRTColors.tagline
        return VStack(alignment: .trailing, spacing: 0) {
            Text("\(value)")
                .font(.caption.monospaced().bold())
                .foregroundStyle(color)
                .accessibilityIdentifier("haulonautResource\(label)")
            Text(label)
                .font(.caption2.monospaced())
                .foregroundStyle(CRTColors.muted)
        }
    }

    private var driftVariancePill: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("\(driftVariance)")
                .font(.caption.monospaced().bold())
                .foregroundStyle(CRTColors.error)
                .accessibilityIdentifier("haulonautResourceDriftVariance")
            Text("Drift")
                .font(.caption2.monospaced())
                .foregroundStyle(CRTColors.error)
        }
        .opacity(reduceMotion ? 1.0 : (driftVariance % 2 == 0 ? 1.0 : 0.5))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.5).repeatForever(), value: driftVariance)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(CRTColors.error)

            Text(error)
                .font(.body.monospaced())
                .foregroundStyle(CRTColors.error)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await loadCharacter() }
            }
            .font(.body.monospaced().bold())
            .foregroundStyle(CRTColors.background)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(CRTColors.title)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .accessibilityIdentifier("haulonautRetryButton")
        }
        .padding()
        .accessibilityIdentifier("haulonautError")
    }

    // MARK: - Game Content

    private var gameContent: some View {
        VStack(spacing: 0) {
            // Main viewport
            ScrollView {
                viewportContent
                    .padding()
            }

            // Bottom bar
            bottomBar
        }
    }

    // MARK: - Viewport Content

    @ViewBuilder
    private var viewportContent: some View {
        switch viewportMode {
        case .space:
            spaceSceneContent
        case .outpost:
            outpostContent
        case .cargo:
            cargoContent
        case .charts:
            chartsContent
        }
    }

    // MARK: - Space Scene

    private var spaceSceneContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Sector header
            Text("SECTOR \(currentSector?.sectorNumber ?? 0)")
                .font(.title2.monospaced().bold())
                .foregroundStyle(CRTColors.title)
                .accessibilityIdentifier("haulonautSectorNumber")

            // Features (planet/outpost)
            if planetFeature != nil || outpostFeature != nil {
                HStack(spacing: 24) {
                    if let planet = planetFeature {
                        planetView(planet)
                    }
                    if let outpost = outpostFeature {
                        outpostIcon(outpost)
                    }
                }
            }

            // Sector description
            if let description = currentSector?.description, !description.isEmpty {
                Text(description)
                    .font(.body.monospaced())
                    .foregroundStyle(CRTColors.description)
            }

            // Players here
            if !playersHere.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pilots here")
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(CRTColors.muted)

                    ForEach(playersHere) { player in
                        Text(player.displayName)
                            .font(.caption.monospaced())
                            .foregroundStyle(CRTColors.tagline)
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Planet View

    private func planetView(_ planet: HaulonautSectorFeature) -> some View {
        let hue = hashHue(planet.name)
        return VStack(spacing: 6) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.55, brightness: 0.85),
                            Color(hue: hue, saturation: 0.7, brightness: 0.35)
                        ],
                        center: .init(x: 0.35, y: 0.32),
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: planetSize, height: planetSize)
                .shadow(color: .white.opacity(0.15), radius: 8)
                .accessibilityHidden(true)

            Text(planet.name)
                .font(.caption2.monospaced())
                .foregroundStyle(CRTColors.description)
        }
    }

    private func outpostIcon(_ outpost: HaulonautSectorFeature) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "building.2")
                .font(.system(size: outpostIconSize))
                .foregroundStyle(CRTColors.title)
                .accessibilityHidden(true)

            Text(outpost.name)
                .font(.caption2.monospaced())
                .foregroundStyle(CRTColors.description)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trading outpost: \(outpost.name)")
    }

    // Deterministic hue from name
    private func hashHue(_ str: String) -> Double {
        var hash = 0
        for char in str {
            hash = (hash &* 31 &+ Int(char.asciiValue ?? 0)) % 360
        }
        return Double(abs(hash)) / 360.0
    }

    // MARK: - Outpost Content

    private var outpostContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text((outpostFeature?.name ?? "Trading Outpost").uppercased())
                .font(.headline.monospaced().bold())
                .foregroundStyle(CRTColors.title)

            if itemsCatalog.isEmpty {
                Text("Nothing for sale right now.")
                    .font(.body.monospaced())
                    .foregroundStyle(CRTColors.muted)
            } else {
                ForEach(itemsCatalog) { item in
                    outpostItemRow(item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func outpostItemRow(_ item: HaulonautItem) -> some View {
        let owned = inventoryQuantity(for: item.itemKey)
        let canAfford = credits >= item.basePrice

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.monospaced().weight(.medium))
                    .foregroundStyle(CRTColors.tagline)

                HStack(spacing: 8) {
                    Text("\(item.basePrice) Credits")
                        .font(.caption.monospaced())
                        .foregroundStyle(CRTColors.description)

                    if owned > 0 {
                        Text("· owned \(owned)")
                            .font(.caption.monospaced())
                            .foregroundStyle(CRTColors.muted)
                    }
                }
            }

            Spacer()

            Button("Buy") {
                Task { await purchase(item) }
            }
            .font(.caption.monospaced().bold())
            .foregroundStyle(canAfford ? CRTColors.background : CRTColors.muted)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(canAfford ? CRTColors.title : CRTColors.border.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .disabled(!canAfford || isPurchasing)
            .accessibilityIdentifier("haulonautBuy_\(item.itemKey)")
            .accessibilityLabel("Buy \(item.name) for \(item.basePrice) Credits")
        }
        .padding()
        .background(CRTColors.border.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Cargo Content

    private var cargoContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CARGO MANIFEST")
                .font(.headline.monospaced().bold())
                .foregroundStyle(CRTColors.title)

            if inventory.isEmpty {
                Text("Cargo hold is empty.")
                    .font(.body.monospaced())
                    .foregroundStyle(CRTColors.muted)
            } else {
                ForEach(inventory) { item in
                    HStack {
                        Text(item.name)
                            .font(.body.monospaced())
                            .foregroundStyle(CRTColors.tagline)

                        Spacer()

                        Text("×\(item.quantity)")
                            .font(.body.monospaced().bold())
                            .foregroundStyle(CRTColors.title)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Star Charts Content

    private var chartsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STAR CHARTS")
                .font(.headline.monospaced().bold())
                .foregroundStyle(CRTColors.title)

            Text("Known locations — tap to plot a course")
                .font(.caption.monospaced())
                .foregroundStyle(CRTColors.muted)

            if knownLocations.isEmpty {
                Text("No locations discovered yet.")
                    .font(.body.monospaced())
                    .foregroundStyle(CRTColors.muted)
            } else {
                ForEach(knownLocations) { location in
                    knownLocationRow(location)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func knownLocationRow(_ location: HaulonautKnownLocation) -> some View {
        let isCurrentSector = location.sectorId == currentSector?.id
        let featureIcon = featureTypeIcon(location.featureType)

        return Button {
            Task { await setCourse(to: location) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: featureIcon)
                    .font(.title3)
                    .foregroundStyle(CRTColors.title)
                    .frame(width: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.name)
                        .font(.subheadline.monospaced().weight(.medium))
                        .foregroundStyle(CRTColors.tagline)

                    Text("Sector \(location.sectorNumber) · \(location.distance) hop\(location.distance == 1 ? "" : "s") away")
                        .font(.caption.monospaced())
                        .foregroundStyle(CRTColors.muted)
                }

                Spacer()

                if isCurrentSector {
                    Text("HERE")
                        .font(.caption2.monospaced().bold())
                        .foregroundStyle(CRTColors.stat)
                } else {
                    Image(systemName: "arrow.right.circle")
                        .foregroundStyle(CRTColors.border)
                }
            }
            .padding()
            .background(CRTColors.border.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .disabled(isCurrentSector || traveling)
        .accessibilityIdentifier("haulonautLocation_\(location.id)")
        .accessibilityLabel("\(location.name), \(location.distance) hops away. \(isCurrentSector ? "Current location" : "Tap to set course")")
    }

    private func featureTypeIcon(_ type: String) -> String {
        switch type {
        case "planet": return "globe"
        case "trading_outpost": return "building.2"
        default: return "star"
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 12) {
            // Autopilot status
            if traveling {
                autopilotStatus
            }

            // Action chips (context-sensitive)
            if viewportMode == .space && !traveling {
                actionChips
            } else if viewportMode != .space {
                backToSectorButton
            }

            // Navigation (warp) buttons
            warpControls
        }
        .padding()
        .background(CRTColors.background.opacity(0.95))
    }

    private var autopilotStatus: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(CRTColors.title)
                .scaleEffect(0.8)

            Text("AUTOPILOT: \(travelDestination ?? "En route")")
                .font(.caption.monospaced().bold())
                .foregroundStyle(CRTColors.stat)

            Text("(\(travelPath.count) hop\(travelPath.count == 1 ? "" : "s") remaining)")
                .font(.caption2.monospaced())
                .foregroundStyle(CRTColors.muted)

            Spacer()

            Button("Abort") {
                abortAutopilot()
            }
            .font(.caption.monospaced().bold())
            .foregroundStyle(CRTColors.error)
        }
    }

    private var actionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if outpostFeature != nil {
                    actionChip(icon: "building.2", label: "Visit Outpost") {
                        visitOutpost()
                    }
                    .accessibilityIdentifier("haulonautVisitOutpostButton")
                }

                if planetFeature != nil {
                    actionChip(icon: "globe", label: "Planet Overview") {
                        showSnackbar("Planetary survey systems are not available yet.")
                    }
                    .accessibilityIdentifier("haulonautPlanetOverviewButton")
                }

                actionChip(icon: "shippingbox", label: "Cargo") {
                    viewCargo()
                }
                .accessibilityIdentifier("haulonautViewCargoButton")

                actionChip(icon: "star.circle", label: "Star Charts") {
                    Task { await viewStarCharts() }
                }
                .accessibilityIdentifier("haulonautStarChartsButton")
            }
        }
    }

    private func actionChip(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.caption.monospaced())
            .foregroundStyle(CRTColors.tagline)
            .padding(.horizontal, chipPadding)
            .padding(.vertical, 8)
            .background(CRTColors.border.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(CRTColors.border, lineWidth: 1)
            }
        }
        .accessibilityInputLabels([label.lowercased()])
    }

    private var backToSectorButton: some View {
        Button {
            exitViewportOverlay()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "xmark")
                Text("Back to Sector")
            }
            .font(.caption.monospaced())
            .foregroundStyle(CRTColors.tagline)
        }
        .accessibilityIdentifier("haulonautBackToSectorButton")
    }

    private var warpControls: some View {
        HStack(spacing: 8) {
            Text("WARP TO")
                .font(.caption2.monospaced())
                .foregroundStyle(CRTColors.muted)

            if connectedSectors.isEmpty {
                Text("no warps available")
                    .font(.caption.monospaced())
                    .foregroundStyle(CRTColors.muted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(connectedSectors) { sector in
                            warpButton(sector)
                        }
                    }
                }
            }
        }
    }

    private func warpButton(_ sector: HaulonautConnectedSector) -> some View {
        let label = sector.visited ? "\(sector.sectorNumber) ✓" : "\(sector.sectorNumber)"
        let isDisabled = isNavigating || !canWarp

        return Button {
            Task { await navigate(to: sector) }
        } label: {
            Text(label)
                .font(.caption.monospaced().bold())
                .foregroundStyle(isDisabled ? CRTColors.muted : CRTColors.tagline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(sector.visited ? CRTColors.border.opacity(0.3) : CRTColors.border.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isDisabled ? CRTColors.muted : CRTColors.border, lineWidth: 1)
                }
        }
        .disabled(isDisabled)
        .accessibilityIdentifier("haulonautWarpButton_\(sector.sectorNumber)")
        .accessibilityLabel("Warp to Sector \(sector.sectorNumber)\(sector.visited ? ", visited" : ", unexplored")\(!canWarp ? ", unavailable - resources depleted" : "")")
    }

    // MARK: - Snackbar

    private func snackbar(_ message: String) -> some View {
        Text(message)
            .font(.caption.monospaced())
            .foregroundStyle(CRTColors.tagline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(CRTColors.border.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onAppear {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    snackbarMessage = nil
                }
            }
    }

    private func showSnackbar(_ message: String) {
        snackbarMessage = message
    }

    // MARK: - Actions

    private func loadCharacter() async {
        isLoading = true
        error = nil

        do {
            let response = try await GamesAPIService.getCharacter(id: characterId)
            character = response.character
            currentSector = response.currentSector
            connectedSectors = response.connectedSectors
            features = response.features
            playersHere = response.playersHere
            credits = response.credits
            rations = response.rations
            fuel = response.fuel
            previousFuel = response.fuel
            inventory = response.inventory

            // Start drift timer
            startDriftTimer()

            // Load items catalog (non-fatal if fails)
            do {
                itemsCatalog = try await GamesAPIService.getItems()
            } catch {
                // Ignore - outpost just shows nothing
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func navigate(to sector: HaulonautConnectedSector) async {
        guard !isNavigating else { return }

        // Abort autopilot if active
        if traveling {
            abortAutopilot()
        }

        isNavigating = true

        do {
            let response = try await GamesAPIService.navigate(characterId: characterId, toSectorId: sector.id)
            currentSector = response.currentSector
            connectedSectors = response.connectedSectors
            features = response.features
            playersHere = response.playersHere
            credits = response.credits
            rations = response.rations
            updateFuel(response.fuel)
            viewportMode = .space
            showSnackbar("Arrived in Sector \(response.currentSector?.sectorNumber ?? 0).")
        } catch {
            showSnackbar(error.localizedDescription)
        }

        isNavigating = false
    }

    private func visitOutpost() {
        let outpostName = outpostFeature?.name ?? "the outpost"
        viewportMode = .outpost
        showSnackbar("Docking at \(outpostName).")
    }

    private func viewCargo() {
        viewportMode = .cargo
        showSnackbar("Pulling up the cargo manifest.")
    }

    private func exitViewportOverlay() {
        let message: String
        switch viewportMode {
        case .outpost:
            message = "Departing the outpost."
        case .cargo:
            message = "Closing the cargo manifest."
        case .charts:
            message = "Closing star charts."
        case .space:
            message = ""
        }
        viewportMode = .space
        if !message.isEmpty {
            showSnackbar(message)
        }
    }

    private func purchase(_ item: HaulonautItem) async {
        guard !isPurchasing else { return }
        isPurchasing = true

        do {
            let response = try await GamesAPIService.purchase(
                characterId: characterId,
                itemKey: item.itemKey,
                quantity: 1
            )
            credits = response.credits
            rations = response.rations
            updateFuel(response.fuel)
            inventory = response.inventory
            showSnackbar("Purchased 1 \(item.name). (-\(item.basePrice) Credits)")
        } catch {
            showSnackbar(error.localizedDescription)
        }

        isPurchasing = false
    }

    // MARK: - Star Charts Actions

    private func viewStarCharts() async {
        do {
            knownLocations = try await GamesAPIService.getKnownLocations(characterId: characterId)
            viewportMode = .charts
            showSnackbar("Opening star charts.")
        } catch {
            showSnackbar("Failed to load star charts: \(error.localizedDescription)")
        }
    }

    private func setCourse(to location: HaulonautKnownLocation) async {
        do {
            let path = try await GamesAPIService.getRoute(characterId: characterId, toSectorId: location.sectorId)
            guard !path.isEmpty else {
                showSnackbar("No route found to \(location.name).")
                return
            }

            travelPath = path
            travelDestination = location.name
            traveling = true
            viewportMode = .space
            showSnackbar("Autopilot engaged to \(location.name).")

            await travelAlongPath()
        } catch {
            showSnackbar("Failed to plot course: \(error.localizedDescription)")
        }
    }

    private func travelAlongPath() async {
        while traveling && !travelPath.isEmpty {
            let nextWaypoint = travelPath.removeFirst()

            do {
                let response = try await GamesAPIService.navigate(characterId: characterId, toSectorId: nextWaypoint.id)
                currentSector = response.currentSector
                connectedSectors = response.connectedSectors
                features = response.features
                playersHere = response.playersHere
                credits = response.credits
                rations = response.rations
                updateFuel(response.fuel)
            } catch {
                showSnackbar("Autopilot error: \(error.localizedDescription)")
                traveling = false
                travelPath = []
                travelDestination = nil
                return
            }

            if travelPath.isEmpty {
                traveling = false
                travelDestination = nil
                showSnackbar("Arrived at destination.")
            } else {
                // Delay between hops (600ms like web)
                try? await Task.sleep(for: .milliseconds(600))
            }
        }
    }

    private func abortAutopilot() {
        traveling = false
        travelPath = []
        travelDestination = nil
        showSnackbar("Autopilot disengaged.")
    }

    // MARK: - Drift Actions

    /// Updates fuel and logs when it crosses 0.
    private func updateFuel(_ newFuel: Int) {
        let oldFuel = fuel
        fuel = newFuel

        // Log when fuel hits 0 or is restored
        if newFuel <= 0 && oldFuel > 0 {
            showSnackbar("WARNING: Fuel depleted. Hull drifting, uncontrolled.")
        } else if newFuel > 0 && oldFuel <= 0 {
            showSnackbar("Fuel restored. Drift variance stabilizing.")
            driftVariance = 0
        }
    }

    /// Starts the drift timer that ticks every second.
    private func startDriftTimer() {
        driftTask?.cancel()
        driftTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
                await driftTick()
            }
        }
    }

    private static let driftThreshold = 30

    /// Called every second. Increases drift variance if eligible, triggers drift when threshold reached.
    @MainActor
    private func driftTick() async {
        // Only drift if eligible (out of fuel and not at a planet)
        guard driftEligible else {
            if driftVariance != 0 {
                driftVariance = 0
            }
            return
        }

        // Don't tick while already drifting or traveling
        guard !drifting && !traveling else { return }

        // Increase variance by 1-3 per tick
        driftVariance += 1 + Int.random(in: 0..<3)

        // Trigger drift when threshold reached
        if driftVariance >= Self.driftThreshold {
            await performDrift()
        }
    }

    /// One hop toward the nearest planet (server-computed).
    private func performDrift() async {
        guard !drifting else { return }
        drifting = true

        do {
            let response = try await GamesAPIService.drift(characterId: characterId)
            currentSector = response.currentSector
            connectedSectors = response.connectedSectors
            features = response.features
            playersHere = response.playersHere
            credits = response.credits
            rations = response.rations
            fuel = response.fuel
            viewportMode = .space
            driftVariance = 0

            showSnackbar("DRIFT: Hull carried into Sector \(response.currentSector?.sectorNumber ?? 0).")

            // If we arrived at a planet, log stabilization
            if planetFeature != nil {
                showSnackbar("A planetary body is in range. Drift variance stabilizing.")
            }
        } catch {
            // Non-fatal - fuel may have been restored or planet reached between ticks
        }

        drifting = false
    }
}

#Preview {
    NavigationStack {
        HaulonautPlayView(characterId: 1)
    }
}
