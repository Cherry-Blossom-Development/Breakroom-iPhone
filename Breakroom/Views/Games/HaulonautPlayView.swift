import SwiftUI
import AVFoundation

// MARK: - Viewport Mode

enum HaulonautViewportMode {
    case space
    case outpost
    case cargo
    case charts
    case buoys     // Tracking buoy telemetry
    case docked    // Inside ship while landed on a planet
    case surface   // On planet surface exploring
    case terminal  // Sector comms terminal
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
    @State private var health: Int = 100
    @State private var cycles: Int = 0
    @State private var cyclesUpdatedAt: Int = 0
    @State private var inventory: [HaulonautInventoryItem] = []
    @State private var itemsCatalog: [HaulonautItem] = []

    // Docking state
    @State private var dockedFeatureId: Int?
    @State private var onSurface: Bool = false
    @State private var surfaceMap: HaulonautSurfaceMap?
    @State private var isDead: Bool = false
    @State private var surfaceNarration: String?

    @State private var viewportMode: HaulonautViewportMode = .space
    @State private var isNavigating = false
    @State private var isPurchasing = false
    @State private var snackbarMessage: String?

    // Star Charts & Autopilot
    @State private var knownLocations: [HaulonautKnownLocation] = []
    @State private var traveling = false
    @State private var travelPath: [HaulonautRouteWaypoint] = []
    @State private var travelDestination: String?

    // Sector chat & interactions
    @State private var sectorMessages: [HaulonautSectorMessage] = []
    @State private var chatInput: String = ""
    @State private var selectedPlayer: HaulonautPlayerHere?
    @State private var showPlayerActions = false
    @State private var tradeOffers: [HaulonautTradeOfferSummary] = []
    @State private var targetInfo: HaulonautTargetInfoResponse?
    @State private var isLoadingTargetInfo = false

    // Trade offer sheet state
    @State private var showTradeSheet = false
    @State private var tradeTargetPlayer: HaulonautPlayerHere?
    @State private var tradeTargetInfo: HaulonautTargetInfoResponse?
    @State private var tradeItemKey: String = ""
    @State private var tradeQuantity: Int = 1
    @State private var tradeCredits: Int = 0

    // Probe state
    @State private var activeProbeMission: HaulonautProbeMission?
    @State private var pendingProbeReport: HaulonautProbeReport?
    @State private var showProbeDeploySheet = false
    @State private var showProbeSearchSheet = false
    @State private var isDeployingProbe = false

    // Tracking buoys state
    @State private var buoys: [HaulonautBuoy] = []
    @State private var isDroppingBuoy = false
    @State private var buoyAttachedAlert: (buoyId: Int, targetDisplayName: String)?

    // Sector arrival alerts (brief banners)
    @State private var sectorArrivalAlerts: [(id: UUID, displayName: String, isNpc: Bool)] = []

    // Incoming trade offer banners
    @State private var incomingTradeOfferBanner: HaulonautTradeOfferSummary?

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

    /// Can't warp if fuel is depleted (rations no longer block, just cause damage).
    var canWarp: Bool {
        fuel > 0
    }

    /// Docked planet feature (if docked).
    var dockedPlanet: HaulonautSectorFeature? {
        guard let dockedId = dockedFeatureId else { return nil }
        return features.first { $0.id == dockedId }
    }

    /// Current cycles computed from wall-clock time (1 cycle per 12 min, cap 120 — migration 068 rebalance).
    var currentCycles: Int {
        guard cyclesUpdatedAt > 0 else { return cycles }
        let now = Int(Date().timeIntervalSince1970)
        let elapsed = max(0, now - cyclesUpdatedAt)
        let accrued = elapsed / 720  // 1 cycle per 12 minutes (720 seconds)
        return min(120, cycles + accrued)
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
            HaulonautSoundService.configureAudioSession()
            setupSocketHandlers()
            HaulonautSocketManager.shared.connect(characterId: characterId)
            await loadCharacter()
            await loadProbeStatus()
        }
        .onDisappear {
            driftTask?.cancel()
            driftTask = nil
            HaulonautSoundService.stopAmbient()
            HaulonautSocketManager.shared.disconnect()
        }
        .onChange(of: viewportMode) { _, newMode in
            updateAmbientSound(for: newMode)
        }
    }

    // MARK: - Resources Display

    private var resourcesDisplay: some View {
        HStack(spacing: 8) {
            soundToggleButton
            resourcePill(label: "HP", value: health, warnAt: 30)
            resourcePill(label: "Cycles", value: currentCycles)
            resourcePill(label: "Tokens", value: credits)
            resourcePill(label: "Rations", value: rations)
            resourcePill(label: "Fuel", value: fuel)
            if driftEligible {
                driftVariancePill
            }
        }
    }

    private var soundToggleButton: some View {
        Button {
            HaulonautSoundService.isMuted.toggle()
            if !HaulonautSoundService.isMuted {
                HaulonautSoundService.play(.click)
                updateAmbientSound(for: viewportMode)
            }
        } label: {
            Image(systemName: HaulonautSoundService.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.caption)
                .foregroundStyle(HaulonautSoundService.isMuted ? CRTColors.muted : CRTColors.tagline)
        }
        .accessibilityIdentifier("haulonautSoundToggle")
        .accessibilityLabel(HaulonautSoundService.isMuted ? "Unmute sounds" : "Mute sounds")
    }

    private func resourcePill(label: String, value: Int, warnAt: Int = 0) -> some View {
        let isWarning = value <= warnAt
        let color = isWarning ? CRTColors.error : CRTColors.tagline
        return VStack(alignment: .trailing, spacing: 0) {
            Text("\(value)")
                .font(.caption.monospaced().bold())
                .foregroundStyle(color)
                .accessibilityIdentifier("haulonautResource\(label)")
            Text(label)
                .font(.caption2.monospaced())
                .foregroundStyle(isWarning ? CRTColors.error : CRTColors.muted)
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
        ZStack {
            VStack(spacing: 0) {
                // Main viewport
                ScrollView {
                    viewportContent
                        .padding()
                }

                // Bottom bar
                bottomBar
            }

            // Overlay banners
            VStack {
                // Sector arrival alerts
                ForEach(sectorArrivalAlerts, id: \.id) { alert in
                    sectorArrivalBanner(displayName: alert.displayName, isNpc: alert.isNpc)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Incoming trade offer banner
                if let offer = incomingTradeOfferBanner {
                    tradeOfferBanner(offer)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Buoy attached alert
                if let alert = buoyAttachedAlert {
                    buoyAttachedBanner(targetDisplayName: alert.targetDisplayName)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
            .padding(.top, 8)
            .animation(.easeInOut(duration: 0.3), value: sectorArrivalAlerts.count)
            .animation(.easeInOut(duration: 0.3), value: incomingTradeOfferBanner?.id)
            .animation(.easeInOut(duration: 0.3), value: buoyAttachedAlert?.buoyId)
        }
    }

    // MARK: - Overlay Banners

    private func sectorArrivalBanner(displayName: String, isNpc: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isNpc ? "cpu" : "person.fill")
                .font(.caption)
                .foregroundStyle(isNpc ? CRTColors.muted : CRTColors.stat)

            Text("\(displayName) entered the sector")
                .font(.caption.monospaced())
                .foregroundStyle(CRTColors.tagline)

            if isNpc {
                Text("[NPC]")
                    .font(.caption2.monospaced())
                    .foregroundStyle(CRTColors.muted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(CRTColors.border.opacity(0.9))
        .clipShape(Capsule())
    }

    private func tradeOfferBanner(_ offer: HaulonautTradeOfferSummary) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(CRTColors.title)

                Text("Trade offer from \(offer.fromDisplayName)")
                    .font(.caption.monospaced().bold())
                    .foregroundStyle(CRTColors.tagline)

                Spacer()

                Button {
                    incomingTradeOfferBanner = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(CRTColors.muted)
                }
            }

            Text("\(offer.quantity)× \(offer.itemName) for \(offer.credits) tokens")
                .font(.caption.monospaced())
                .foregroundStyle(CRTColors.description)

            HStack(spacing: 12) {
                Button {
                    Task { await acceptTradeOffer(offer) }
                } label: {
                    Text("Accept")
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(CRTColors.background)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(CRTColors.stat)
                        .clipShape(Capsule())
                }

                Button {
                    Task { await declineTradeOffer(offer) }
                } label: {
                    Text("Decline")
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(CRTColors.muted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(CRTColors.border.opacity(0.3))
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(CRTColors.background.opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(CRTColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    private func buoyAttachedBanner(targetDisplayName: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundStyle(CRTColors.stat)

            Text("Buoy attached to \(targetDisplayName)")
                .font(.caption.monospaced().bold())
                .foregroundStyle(CRTColors.tagline)

            Spacer()

            Button {
                buoyAttachedAlert = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(CRTColors.muted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(CRTColors.stat.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(CRTColors.stat, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    // MARK: - Viewport Content

    @ViewBuilder
    private var viewportContent: some View {
        if isDead {
            deathContent
        } else {
            switch viewportMode {
            case .space:
                spaceSceneContent
            case .outpost:
                outpostContent
            case .cargo:
                cargoContent
            case .charts:
                chartsContent
            case .buoys:
                buoysContent
            case .docked:
                dockedContent
            case .surface:
                surfaceContent
            case .terminal:
                terminalContent
            }
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
                        playerRow(player)
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showPlayerActions) {
            if let player = selectedPlayer {
                playerActionsSheet(player)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showTradeSheet) {
            if let player = tradeTargetPlayer {
                tradeOfferSheet(player)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Player Row

    private func playerRow(_ player: HaulonautPlayerHere) -> some View {
        Button {
            HaulonautSoundService.play(.click)
            selectedPlayer = player
            showPlayerActions = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundStyle(player.isNpc ? CRTColors.muted : CRTColors.stat)

                Text(player.displayName)
                    .font(.caption.monospaced())
                    .foregroundStyle(CRTColors.tagline)

                if player.isNpc {
                    Text("[NPC]")
                        .font(.caption2.monospaced())
                        .foregroundStyle(CRTColors.muted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(CRTColors.muted)
            }
            .padding(.vertical, 4)
        }
        .accessibilityIdentifier("haulonautPlayer_\(player.id)")
        .accessibilityLabel("\(player.displayName)\(player.isNpc ? ", NPC" : ""). Tap for actions.")
    }

    private func playerActionsSheet(_ player: HaulonautPlayerHere) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Player info
                    VStack(spacing: 8) {
                        Image(systemName: player.isNpc ? "cpu" : "person.fill")
                            .font(.largeTitle)
                            .foregroundStyle(player.isNpc ? CRTColors.muted : CRTColors.title)

                        Text(player.displayName)
                            .font(.title2.monospaced().bold())
                            .foregroundStyle(CRTColors.tagline)

                        if player.isNpc {
                            Text("NPC Pilot")
                                .font(.caption.monospaced())
                                .foregroundStyle(CRTColors.muted)
                        }
                    }
                    .padding(.top, 16)

                    // Cargo preview
                    targetCargoPreview

                    // Actions
                    VStack(spacing: 12) {
                        // Propose Trade (both NPCs and humans)
                        Button {
                            showPlayerActions = false
                            tradeTargetPlayer = player
                            tradeTargetInfo = targetInfo
                            showTradeSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Propose Trade")
                            }
                            .font(.body.monospaced())
                            .foregroundStyle(CRTColors.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(CRTColors.title)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .accessibilityIdentifier("haulonautProposeTradeButton")

                        if !player.isNpc {
                            // Give tokens
                            Button {
                                showPlayerActions = false
                                Task { await giveTokens(to: player) }
                            } label: {
                                HStack {
                                    Image(systemName: "gift")
                                    Text("Give Tokens")
                                }
                                .font(.body.monospaced())
                                .foregroundStyle(CRTColors.background)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(CRTColors.stat)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .accessibilityIdentifier("haulonautGiveTokensButton")
                        }

                        // Attack
                        Button {
                            showPlayerActions = false
                            Task { await attackPlayer(player) }
                        } label: {
                            HStack {
                                Image(systemName: "flame")
                                Text("Attack")
                            }
                            .font(.body.monospaced())
                            .foregroundStyle(CRTColors.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(CRTColors.error)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .accessibilityIdentifier("haulonautAttackButton")
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .background(CRTColors.background)
            .task {
                await loadTargetInfo(for: player)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showPlayerActions = false
                        targetInfo = nil
                    }
                    .font(.body.monospaced())
                    .foregroundStyle(CRTColors.tagline)
                }
            }
            .toolbarBackground(CRTColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var targetCargoPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THEIR CARGO")
                .font(.caption.monospaced().bold())
                .foregroundStyle(CRTColors.muted)

            if isLoadingTargetInfo {
                HStack {
                    ProgressView()
                        .tint(CRTColors.title)
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption.monospaced())
                        .foregroundStyle(CRTColors.muted)
                }
            } else if let info = targetInfo {
                if info.inventory.isEmpty {
                    Text("Empty cargo hold")
                        .font(.caption.monospaced())
                        .foregroundStyle(CRTColors.muted)
                } else {
                    ForEach(info.inventory) { item in
                        HStack {
                            Text(item.name)
                                .font(.caption.monospaced())
                                .foregroundStyle(CRTColors.description)
                            Spacer()
                            Text("x\(item.quantity)")
                                .font(.caption.monospaced().bold())
                                .foregroundStyle(CRTColors.tagline)
                        }
                    }
                }
            } else {
                Text("Unable to scan cargo")
                    .font(.caption.monospaced())
                    .foregroundStyle(CRTColors.muted)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CRTColors.border.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 24)
    }

    private func loadTargetInfo(for player: HaulonautPlayerHere) async {
        isLoadingTargetInfo = true
        targetInfo = nil

        do {
            targetInfo = try await GamesAPIService.getTargetInfo(
                characterId: characterId,
                targetId: player.id
            )
        } catch {
            // Non-fatal - just show "unable to scan"
        }

        isLoadingTargetInfo = false
    }

    // MARK: - Trade Offer Sheet

    private func tradeOfferSheet(_ player: HaulonautPlayerHere) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Trade with \(player.displayName)")
                    .font(.headline.monospaced())
                    .foregroundStyle(CRTColors.tagline)
                    .padding(.top, 16)

                // Item selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("OFFER ITEM")
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(CRTColors.muted)

                    if inventory.isEmpty {
                        Text("No items in cargo")
                            .font(.body.monospaced())
                            .foregroundStyle(CRTColors.muted)
                    } else {
                        Picker("Item", selection: $tradeItemKey) {
                            Text("Select item...").tag("")
                            ForEach(inventory) { item in
                                Text("\(item.name) (x\(item.quantity))")
                                    .tag(item.itemKey)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(CRTColors.title)
                    }
                }
                .padding(.horizontal, 24)

                // Quantity stepper
                if !tradeItemKey.isEmpty {
                    let maxQty = inventory.first { $0.itemKey == tradeItemKey }?.quantity ?? 1

                    VStack(alignment: .leading, spacing: 8) {
                        Text("QUANTITY")
                            .font(.caption.monospaced().bold())
                            .foregroundStyle(CRTColors.muted)

                        Stepper(value: $tradeQuantity, in: 1...maxQty) {
                            Text("\(tradeQuantity)")
                                .font(.body.monospaced().bold())
                                .foregroundStyle(CRTColors.tagline)
                        }
                        .tint(CRTColors.title)
                    }
                    .padding(.horizontal, 24)
                }

                // Credits input
                VStack(alignment: .leading, spacing: 8) {
                    Text("REQUEST TOKENS")
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(CRTColors.muted)

                    TextField("0", value: $tradeCredits, format: .number)
                        .font(.body.monospaced())
                        .foregroundStyle(CRTColors.tagline)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(CRTColors.border.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.horizontal, 24)

                // Submit button
                Button {
                    Task { await submitTradeOffer(to: player) }
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Send Offer")
                    }
                    .font(.body.monospaced().bold())
                    .foregroundStyle(CRTColors.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(tradeItemKey.isEmpty ? CRTColors.muted : CRTColors.title)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .disabled(tradeItemKey.isEmpty)
                .padding(.horizontal, 24)
                .accessibilityIdentifier("haulonautSubmitTradeButton")

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(CRTColors.background)
            .onAppear {
                // Reset form when sheet appears
                tradeItemKey = ""
                tradeQuantity = 1
                tradeCredits = 0
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showTradeSheet = false
                    }
                    .font(.body.monospaced())
                    .foregroundStyle(CRTColors.muted)
                }
            }
            .toolbarBackground(CRTColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func submitTradeOffer(to player: HaulonautPlayerHere) async {
        guard !tradeItemKey.isEmpty else { return }

        HaulonautSoundService.play(.click)

        do {
            let response = try await GamesAPIService.createTradeOffer(
                characterId: characterId,
                toCharacterId: player.id,
                itemKey: tradeItemKey,
                quantity: tradeQuantity,
                credits: tradeCredits
            )
            showTradeSheet = false
            HaulonautSoundService.play(.success)
            showSnackbar(response.message ?? "Trade offer sent to \(player.displayName).")
        } catch {
            HaulonautSoundService.play(.error)
            showSnackbar("Error: \(error.localizedDescription)")
        }
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
                    cargoItemRow(item)
                }
            }

            // Probe section
            Divider()
                .background(CRTColors.border)
                .padding(.vertical, 8)

            probeSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showProbeDeploySheet) {
            probeDeploySheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func cargoItemRow(_ item: HaulonautInventoryItem) -> some View {
        if item.itemKey == "tracking_buoy" {
            Button {
                HaulonautSoundService.play(.click)
                Task { await dropBuoy() }
            } label: {
                HStack {
                    Text(item.name)
                        .font(.body.monospaced())
                        .foregroundStyle(CRTColors.tagline)

                    Spacer()

                    Text("×\(item.quantity)")
                        .font(.body.monospaced().bold())
                        .foregroundStyle(CRTColors.title)

                    Image(systemName: "arrow.down.circle")
                        .font(.caption)
                        .foregroundStyle(CRTColors.stat)
                }
            }
            .disabled(isDroppingBuoy)
            .accessibilityLabel("Drop \(item.name) in current sector")
        } else {
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

    // MARK: - Probe Section

    private var probeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PROBES")
                .font(.subheadline.monospaced().bold())
                .foregroundStyle(CRTColors.title)

            let probeCount = inventoryQuantity(for: "probe")

            if let mission = activeProbeMission {
                // Active mission status
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(CRTColors.stat)
                        Text("Mission: \(mission.missionType.replacingOccurrences(of: "_", with: " ").capitalized)")
                            .font(.caption.monospaced())
                            .foregroundStyle(CRTColors.tagline)
                    }

                    ProgressView(value: mission.progress)
                        .tint(CRTColors.stat)
                        .accessibilityLabel("Probe progress \(Int(mission.progress * 100)) percent")

                    Text("\(mission.ticksElapsed)/\(mission.ticksToComplete) ticks")
                        .font(.caption2.monospaced())
                        .foregroundStyle(CRTColors.muted)
                }
                .padding()
                .background(CRTColors.border.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if let report = pendingProbeReport {
                // Pending report
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(CRTColors.title)
                        Text("PROBE REPORT READY")
                            .font(.caption.monospaced().bold())
                            .foregroundStyle(CRTColors.title)
                    }

                    Text(report.summary)
                        .font(.caption.monospaced())
                        .foregroundStyle(CRTColors.tagline)

                    Button {
                        Task { await acknowledgeProbeReport() }
                    } label: {
                        Text("Acknowledge")
                            .font(.caption.monospaced().bold())
                            .foregroundStyle(CRTColors.background)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(CRTColors.stat)
                            .clipShape(Capsule())
                    }
                }
                .padding()
                .background(CRTColors.border.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                // No active mission
                HStack {
                    Text("Probes: \(probeCount)")
                        .font(.caption.monospaced())
                        .foregroundStyle(CRTColors.muted)

                    Spacer()

                    if probeCount > 0 {
                        Button {
                            HaulonautSoundService.play(.click)
                            showProbeDeploySheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "paperplane.fill")
                                Text("Deploy")
                            }
                            .font(.caption.monospaced().bold())
                            .foregroundStyle(CRTColors.background)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(CRTColors.stat)
                            .clipShape(Capsule())
                        }
                        .disabled(isDeployingProbe)
                        .accessibilityIdentifier("haulonautDeployProbe")
                    }
                }
            }
        }
    }

    // MARK: - Probe Deploy Sheet

    private var probeDeploySheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Select Mission Type")
                    .font(.headline.monospaced())
                    .foregroundStyle(CRTColors.tagline)

                VStack(spacing: 12) {
                    probeMissionButton(type: "scout_sector", label: "Scout Sector", description: "Scan current sector for activity", icon: "eye.fill")
                    probeMissionButton(type: "locate_item", label: "Locate Item", description: "Search for trade goods", icon: "magnifyingglass")
                    probeMissionButton(type: "track_pilot", label: "Track Pilot", description: "Find another pilot's location", icon: "location.fill")
                }

                Spacer()
            }
            .padding()
            .background(CRTColors.background)
            .navigationTitle("Deploy Probe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showProbeDeploySheet = false
                    }
                    .foregroundStyle(CRTColors.muted)
                }
            }
        }
        .presentationBackground(CRTColors.background)
    }

    private func probeMissionButton(type: String, label: String, description: String, icon: String) -> some View {
        Button {
            Task { await deployProbe(missionType: type) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(CRTColors.title)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline.monospaced().bold())
                        .foregroundStyle(CRTColors.tagline)

                    Text(description)
                        .font(.caption.monospaced())
                        .foregroundStyle(CRTColors.muted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(CRTColors.border)
            }
            .padding()
            .background(CRTColors.border.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(isDeployingProbe)
        .accessibilityIdentifier("haulonautProbeMission_\(type)")
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

    // MARK: - Buoys Content

    private var buoysContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRACKING BUOYS")
                .font(.headline.monospaced().bold())
                .foregroundStyle(CRTColors.title)

            Text("Deployed buoys and their targets")
                .font(.caption.monospaced())
                .foregroundStyle(CRTColors.muted)

            if buoys.isEmpty {
                Text("No buoys deployed yet.")
                    .font(.body.monospaced())
                    .foregroundStyle(CRTColors.muted)

                Text("Purchase Magnetic Tracking Buoys from an outpost, then drop them from your Cargo.")
                    .font(.caption.monospaced())
                    .foregroundStyle(CRTColors.muted)
                    .padding(.top, 4)
            } else {
                ForEach(buoys) { buoy in
                    buoyRow(buoy)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buoyRow(_ buoy: HaulonautBuoy) -> some View {
        HStack(spacing: 12) {
            Image(systemName: buoy.status == "attached" ? "location.fill" : "circle.dotted")
                .font(.title3)
                .foregroundStyle(buoy.status == "attached" ? CRTColors.stat : CRTColors.muted)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                if buoy.status == "attached", let target = buoy.targetDisplayName {
                    Text("Tracking \(target)")
                        .font(.subheadline.monospaced().weight(.medium))
                        .foregroundStyle(CRTColors.tagline)

                    Text("Currently in Sector \(buoy.sectorNumber)")
                        .font(.caption.monospaced())
                        .foregroundStyle(CRTColors.stat)
                } else {
                    Text("Waiting in Sector \(buoy.sectorNumber)")
                        .font(.subheadline.monospaced().weight(.medium))
                        .foregroundStyle(CRTColors.muted)

                    Text("Not yet attached")
                        .font(.caption.monospaced())
                        .foregroundStyle(CRTColors.muted)
                }
            }

            Spacer()
        }
        .padding()
        .background(CRTColors.border.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel(buoy.status == "attached"
            ? "Tracking \(buoy.targetDisplayName ?? "unknown") in Sector \(buoy.sectorNumber)"
            : "Buoy waiting in Sector \(buoy.sectorNumber)")
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
                    actionChip(icon: "globe", label: "Land on Planet") {
                        Task { await dockAtPlanet() }
                    }
                    .accessibilityIdentifier("haulonautLandOnPlanetButton")
                }

                actionChip(icon: "shippingbox", label: "Cargo") {
                    viewCargo()
                }
                .accessibilityIdentifier("haulonautViewCargoButton")

                actionChip(icon: "star.circle", label: "Star Charts") {
                    Task { await viewStarCharts() }
                }
                .accessibilityIdentifier("haulonautStarChartsButton")

                actionChip(icon: "antenna.radiowaves.left.and.right", label: "Buoys") {
                    Task { await viewBuoys() }
                }
                .accessibilityIdentifier("haulonautBuoysButton")

                actionChip(icon: "terminal", label: "Terminal") {
                    HaulonautSoundService.play(.open)
                    viewportMode = .terminal
                    showSnackbar("Opening sector comms terminal.")
                }
                .accessibilityIdentifier("haulonautTerminalButton")
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

    private func updateAmbientSound(for mode: HaulonautViewportMode) {
        switch mode {
        case .space, .charts, .buoys, .cargo, .terminal:
            HaulonautSoundService.playAmbient(.space)
        case .outpost:
            HaulonautSoundService.playAmbient(.outpost)
        case .docked, .surface:
            HaulonautSoundService.playAmbient(.surface)
        }
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
            health = response.health
            cycles = response.cycles
            cyclesUpdatedAt = response.cyclesUpdatedAt
            inventory = response.inventory
            dockedFeatureId = response.dockedFeatureId
            onSurface = response.onSurface
            surfaceMap = response.surfaceMap
            isDead = response.character.status == "dead"

            // Set initial viewport based on state
            if isDead {
                viewportMode = .space
            } else if onSurface {
                viewportMode = .surface
            } else if dockedFeatureId != nil {
                viewportMode = .docked
            } else {
                viewportMode = .space
            }

            // Play presence sound if other pilots are in sector
            if !playersHere.isEmpty {
                let hasNpc = playersHere.contains { $0.isNpc }
                let hasHuman = playersHere.contains { !$0.isNpc }
                if hasNpc {
                    HaulonautSoundService.play(.npcPresence)
                } else if hasHuman {
                    HaulonautSoundService.play(.presence)
                }
            }

            // Start ambient sound
            updateAmbientSound(for: viewportMode)

            // Start drift timer
            startDriftTimer()

            // Join sector socket room
            if let sectorId = currentSector?.id {
                HaulonautSocketManager.shared.joinSector(sectorId)
            }

            // Load items catalog (non-fatal if fails)
            do {
                itemsCatalog = try await GamesAPIService.getItems()
            } catch {
                // Ignore - outpost just shows nothing
            }

            // Load pending trade offers
            await loadTradeOffers()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func setupSocketHandlers() {
        let socketManager = HaulonautSocketManager.shared

        // Sector chat message
        socketManager.onSectorMessage = { [self] message in
            // Don't add our own echoed messages
            if message.characterId != characterId {
                sectorMessages.append(message)
                HaulonautSoundService.play(.notify)
            }
        }

        // Pilot entered sector
        socketManager.onSectorArrival = { [self] pilotId, displayName, isNpc in
            // Add to playersHere if not already there
            if !playersHere.contains(where: { $0.id == pilotId }) {
                let player = HaulonautPlayerHere(id: pilotId, displayName: displayName, isNpc: isNpc)
                playersHere.append(player)
            }

            // Show brief alert banner
            let alert = (id: UUID(), displayName: displayName, isNpc: isNpc)
            sectorArrivalAlerts.append(alert)
            HaulonautSoundService.play(isNpc ? .npcPresence : .presence)

            // Auto-dismiss after 3 seconds
            Task {
                try? await Task.sleep(for: .seconds(3))
                sectorArrivalAlerts.removeAll { $0.id == alert.id }
            }
        }

        // Gift received
        socketManager.onGiftReceived = { [self] fromDisplayName, amount in
            credits += amount
            addSystemMessage("\(fromDisplayName) sent you \(amount) tokens!")
            HaulonautSoundService.play(.success)
        }

        // Trade offer received
        socketManager.onTradeOffer = { [self] offer in
            // Only show if we're the target
            if offer.toGameUserId == characterId {
                tradeOffers.append(offer)
                incomingTradeOfferBanner = offer
                HaulonautSoundService.play(.notify)

                // Auto-dismiss banner after 10 seconds
                Task {
                    try? await Task.sleep(for: .seconds(10))
                    if incomingTradeOfferBanner?.id == offer.id {
                        incomingTradeOfferBanner = nil
                    }
                }
            }
        }

        // Trade resolved
        socketManager.onTradeResolved = { [self] offerId, accepted in
            tradeOffers.removeAll { $0.id == offerId }
            if incomingTradeOfferBanner?.id == offerId {
                incomingTradeOfferBanner = nil
            }
            HaulonautSoundService.play(accepted ? .tradeSuccess : .tradeDecline)
        }

        // Probe report
        socketManager.onProbeReport = { [self] report in
            pendingProbeReport = report
            activeProbeMission = nil
            HaulonautSoundService.play(.notify)
            addSystemMessage("PROBE REPORT: \(report.summary)")
        }

        // Combat event
        socketManager.onCombatEvent = { [self] attackerName, targetName, damage, targetDied in
            let myName = character?.displayName ?? ""
            if targetName == myName {
                // We got hit
                HaulonautSoundService.play(.damage)
                if targetDied {
                    addSystemMessage("CRITICAL: \(attackerName) destroyed your ship!")
                } else {
                    addSystemMessage("\(attackerName) hit you for \(damage) damage!")
                }
            } else if attackerName == myName {
                // We attacked (already handled by attackPlayer)
            } else {
                // Someone else in sector
                if targetDied {
                    addSystemMessage("\(attackerName) destroyed \(targetName)!")
                } else {
                    addSystemMessage("\(attackerName) attacked \(targetName) for \(damage) damage.")
                }
            }
        }

        // Buoy attached event
        socketManager.onBuoyAttached = { [self] buoyId, targetDisplayName in
            buoyAttachedAlert = (buoyId: buoyId, targetDisplayName: targetDisplayName)
            addSystemMessage("[BUOY] Your tracking buoy just attached to \(targetDisplayName)'s ship.")
            HaulonautSoundService.play(.notify)

            // Auto-dismiss after 5 seconds
            Task {
                try? await Task.sleep(for: .seconds(5))
                if buoyAttachedAlert?.buoyId == buoyId {
                    buoyAttachedAlert = nil
                }
            }

            // Refresh buoys if on buoys screen
            if viewportMode == .buoys {
                Task { buoys = (try? await GamesAPIService.getBuoys(characterId: characterId)) ?? buoys }
            }
        }
    }

    private func loadProbeStatus() async {
        do {
            let response = try await GamesAPIService.getProbes(characterId: characterId)
            activeProbeMission = response.activeMission
            pendingProbeReport = response.pendingReport
        } catch {
            // Non-fatal
        }
    }

    private func deployProbe(missionType: String) async {
        guard !isDeployingProbe else { return }
        isDeployingProbe = true
        showProbeDeploySheet = false

        do {
            let response = try await GamesAPIService.deployProbe(
                characterId: characterId,
                missionType: missionType,
                searchItemKey: nil
            )
            if let probe = response.probe {
                activeProbeMission = probe
                // Update inventory (reduce probe count)
                if let idx = inventory.firstIndex(where: { $0.itemKey == "probe" }) {
                    let current = inventory[idx]
                    if current.quantity > 1 {
                        inventory[idx] = HaulonautInventoryItem(
                            itemKey: current.itemKey,
                            name: current.name,
                            category: current.category,
                            quantity: current.quantity - 1
                        )
                    } else {
                        inventory.remove(at: idx)
                    }
                }
                HaulonautSoundService.play(.success)
                showSnackbar(response.message ?? "Probe deployed!")
            }
        } catch {
            HaulonautSoundService.play(.error)
            showSnackbar("Failed to deploy probe: \(error.localizedDescription)")
        }

        isDeployingProbe = false
    }

    private func acknowledgeProbeReport() async {
        guard let report = pendingProbeReport else { return }

        do {
            _ = try await GamesAPIService.acknowledgeProbeReport(characterId: characterId, missionId: report.id)
            pendingProbeReport = nil
            HaulonautSoundService.play(.click)
        } catch {
            showSnackbar("Failed to acknowledge report: \(error.localizedDescription)")
        }
    }

    private func navigate(to sector: HaulonautConnectedSector) async {
        guard !isNavigating else { return }

        // Abort autopilot if active
        if traveling {
            abortAutopilot()
        }

        isNavigating = true
        HaulonautSoundService.play(.warp)

        do {
            let response = try await GamesAPIService.navigate(characterId: characterId, toSectorId: sector.id)
            currentSector = response.currentSector
            connectedSectors = response.connectedSectors
            features = response.features
            playersHere = response.playersHere
            credits = response.credits
            rations = response.rations
            updateFuel(response.fuel)
            health = response.health
            cycles = response.cycles
            cyclesUpdatedAt = response.cyclesUpdatedAt
            dockedFeatureId = response.dockedFeatureId
            onSurface = response.onSurface
            surfaceMap = response.surfaceMap
            viewportMode = .space

            if response.died {
                isDead = true
                HaulonautSoundService.play(.death)
                showSnackbar("CRITICAL: Crew health depleted. Your voyage has ended.")
            } else {
                HaulonautSoundService.play(.arrival)
                showSnackbar("Arrived in Sector \(response.currentSector?.sectorNumber ?? 0).")
            }
        } catch {
            HaulonautSoundService.play(.error)
            showSnackbar(error.localizedDescription)
        }

        isNavigating = false
    }

    private func visitOutpost() {
        let outpostName = outpostFeature?.name ?? "the outpost"
        HaulonautSoundService.play(.open)
        viewportMode = .outpost
        showSnackbar("Docking at \(outpostName).")
    }

    private func viewCargo() {
        HaulonautSoundService.play(.open)
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
        case .buoys:
            message = "Closing buoy telemetry."
        case .terminal:
            message = "Closing terminal."
        case .docked:
            message = ""  // Handled by launch action
        case .surface:
            message = ""  // Handled by return to ship action
        case .space:
            message = ""
        }
        // For docked/surface, don't just switch to space - need proper actions
        if viewportMode != .docked && viewportMode != .surface {
            viewportMode = .space
        }
        if !message.isEmpty {
            showSnackbar(message)
        }
    }

    private func purchase(_ item: HaulonautItem) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        HaulonautSoundService.play(.click)

        do {
            let response = try await GamesAPIService.purchase(
                characterId: characterId,
                itemKey: item.itemKey,
                quantity: 1
            )
            credits = response.credits
            rations = response.rations
            updateFuel(response.fuel)
            health = response.health
            cycles = response.cycles
            cyclesUpdatedAt = response.cyclesUpdatedAt
            inventory = response.inventory
            HaulonautSoundService.play(.success)
            showSnackbar("Purchased 1 \(item.name). (-\(item.basePrice) Credits)")
        } catch {
            HaulonautSoundService.play(.error)
            showSnackbar(error.localizedDescription)
        }

        isPurchasing = false
    }

    // MARK: - Star Charts Actions

    private func viewStarCharts() async {
        HaulonautSoundService.play(.open)
        do {
            knownLocations = try await GamesAPIService.getKnownLocations(characterId: characterId)
            viewportMode = .charts
            showSnackbar("Opening star charts.")
        } catch {
            HaulonautSoundService.play(.error)
            showSnackbar("Failed to load star charts: \(error.localizedDescription)")
        }
    }

    // MARK: - Buoys Actions

    private func viewBuoys() async {
        HaulonautSoundService.play(.open)
        do {
            buoys = try await GamesAPIService.getBuoys(characterId: characterId)
            viewportMode = .buoys
            showSnackbar("Checking tracking buoy telemetry.")
        } catch {
            HaulonautSoundService.play(.error)
            showSnackbar("Failed to load buoys: \(error.localizedDescription)")
        }
    }

    private func dropBuoy() async {
        guard !isDroppingBuoy else { return }
        isDroppingBuoy = true

        do {
            let response = try await GamesAPIService.dropBuoy(characterId: characterId)
            inventory = response.inventory
            buoys = response.buoys
            HaulonautSoundService.play(.success)
            showSnackbar(response.message)
            viewportMode = .space
        } catch {
            HaulonautSoundService.play(.error)
            showSnackbar("Failed to drop buoy: \(error.localizedDescription)")
        }

        isDroppingBuoy = false
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
                health = response.health
                cycles = response.cycles
                cyclesUpdatedAt = response.cyclesUpdatedAt
                dockedFeatureId = response.dockedFeatureId
                onSurface = response.onSurface
                surfaceMap = response.surfaceMap

                // Check for death during travel
                if response.died {
                    isDead = true
                    traveling = false
                    travelPath = []
                    travelDestination = nil
                    showSnackbar("CRITICAL: Crew health depleted. Your voyage has ended.")
                    return
                }
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

        HaulonautSoundService.play(.drift)

        do {
            let response = try await GamesAPIService.drift(characterId: characterId)
            currentSector = response.currentSector
            connectedSectors = response.connectedSectors
            features = response.features
            playersHere = response.playersHere
            credits = response.credits
            rations = response.rations
            fuel = response.fuel
            health = response.health
            cycles = response.cycles
            cyclesUpdatedAt = response.cyclesUpdatedAt
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

    // MARK: - Death Content

    private var deathContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "xmark.octagon")
                .font(.system(size: 64))
                .foregroundStyle(CRTColors.error)

            Text("VOYAGE ENDED")
                .font(.title.monospaced().bold())
                .foregroundStyle(CRTColors.error)

            Text("Your crew's health has been depleted. This character can no longer continue.")
                .font(.body.monospaced())
                .foregroundStyle(CRTColors.muted)
                .multilineTextAlignment(.center)

            Button("Return to Games") {
                dismiss()
            }
            .font(.body.monospaced().bold())
            .foregroundStyle(CRTColors.background)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(CRTColors.error)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding()
    }

    // MARK: - Docked Content

    private var dockedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DOCKED")
                .font(.headline.monospaced().bold())
                .foregroundStyle(CRTColors.title)

            if let planet = dockedPlanet {
                Text("Landed at \(planet.name)")
                    .font(.body.monospaced())
                    .foregroundStyle(CRTColors.tagline)

                if let description = planet.description, !description.isEmpty {
                    Text(description)
                        .font(.caption.monospaced())
                        .foregroundStyle(CRTColors.description)
                }
            }

            HStack(spacing: 16) {
                Button {
                    Task { await exitCraft() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.walk")
                        Text("Exit Craft")
                    }
                    .font(.subheadline.monospaced().bold())
                    .foregroundStyle(CRTColors.background)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(CRTColors.title)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .accessibilityIdentifier("haulonautExitCraftButton")

                Button {
                    Task { await launchShip() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle")
                        Text("Launch")
                    }
                    .font(.subheadline.monospaced().bold())
                    .foregroundStyle(CRTColors.tagline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(CRTColors.border.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(CRTColors.border, lineWidth: 1)
                    }
                }
                .accessibilityIdentifier("haulonautLaunchButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Surface Content

    private var surfaceContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SURFACE EXPLORATION")
                .font(.headline.monospaced().bold())
                .foregroundStyle(CRTColors.title)

            if let planet = dockedPlanet {
                Text(planet.name)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(CRTColors.tagline)
            }

            // Surface narration
            if let narration = surfaceNarration {
                Text(narration)
                    .font(.caption.monospaced())
                    .foregroundStyle(CRTColors.description)
                    .padding()
                    .background(CRTColors.border.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Surface grid
            if let map = surfaceMap {
                surfaceGridView(map)
            }

            // D-pad controls
            dpadControls

            // Return to ship button (only when at ship location)
            if let map = surfaceMap, map.buggyX == map.shipX && map.buggyY == map.shipY {
                Button {
                    Task { await returnToShip() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "airplane")
                        Text("Return to Ship")
                    }
                    .font(.subheadline.monospaced().bold())
                    .foregroundStyle(CRTColors.background)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(CRTColors.title)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .accessibilityIdentifier("haulonautReturnToShipButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func surfaceGridView(_ map: HaulonautSurfaceMap) -> some View {
        let cellSize: CGFloat = 24

        return VStack(spacing: 2) {
            ForEach(0..<map.gridHeight, id: \.self) { y in
                HStack(spacing: 2) {
                    ForEach(0..<map.gridWidth, id: \.self) { x in
                        let cellIndex = y * map.gridWidth + x
                        let isRevealed = map.revealed.contains(cellIndex)
                        let isShip = x == map.shipX && y == map.shipY
                        let isBuggy = x == map.buggyX && y == map.buggyY

                        ZStack {
                            Rectangle()
                                .fill(isRevealed ? CRTColors.border.opacity(0.3) : CRTColors.border.opacity(0.1))

                            if isShip {
                                Image(systemName: "airplane")
                                    .font(.caption2)
                                    .foregroundStyle(CRTColors.stat)
                            }
                            if isBuggy {
                                Image(systemName: "car.side")
                                    .font(.caption2)
                                    .foregroundStyle(CRTColors.title)
                            }
                        }
                        .frame(width: cellSize, height: cellSize)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
            }
        }
    }

    private var dpadControls: some View {
        VStack(spacing: 4) {
            Button { Task { await driveBuggy("up") } } label: {
                Image(systemName: "chevron.up")
                    .font(.title2)
                    .foregroundStyle(CRTColors.tagline)
                    .frame(width: 44, height: 44)
                    .background(CRTColors.border.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .accessibilityIdentifier("haulonautDpadUp")

            HStack(spacing: 4) {
                Button { Task { await driveBuggy("left") } } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundStyle(CRTColors.tagline)
                        .frame(width: 44, height: 44)
                        .background(CRTColors.border.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .accessibilityIdentifier("haulonautDpadLeft")

                Color.clear
                    .frame(width: 44, height: 44)

                Button { Task { await driveBuggy("right") } } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundStyle(CRTColors.tagline)
                        .frame(width: 44, height: 44)
                        .background(CRTColors.border.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .accessibilityIdentifier("haulonautDpadRight")
            }

            Button { Task { await driveBuggy("down") } } label: {
                Image(systemName: "chevron.down")
                    .font(.title2)
                    .foregroundStyle(CRTColors.tagline)
                    .frame(width: 44, height: 44)
                    .background(CRTColors.border.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .accessibilityIdentifier("haulonautDpadDown")
        }
    }

    // MARK: - Terminal Content (Sector Chat)

    private var terminalContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SECTOR COMMS TERMINAL")
                .font(.headline.monospaced().bold())
                .foregroundStyle(CRTColors.title)

            Text("Sector \(currentSector?.sectorNumber ?? 0) — \(playersHere.count) pilot\(playersHere.count == 1 ? "" : "s") online")
                .font(.caption.monospaced())
                .foregroundStyle(CRTColors.muted)

            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if sectorMessages.isEmpty {
                            Text("No messages yet. Say something!")
                                .font(.caption.monospaced())
                                .foregroundStyle(CRTColors.muted)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(sectorMessages) { message in
                                sectorMessageRow(message)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 300)
                .background(CRTColors.border.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: sectorMessages.count) {
                    if let lastMessage = sectorMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Chat input
            HStack(spacing: 8) {
                TextField("Message...", text: $chatInput)
                    .font(.body.monospaced())
                    .foregroundStyle(CRTColors.tagline)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(CRTColors.border.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityIdentifier("haulonautChatInput")

                Button {
                    sendChatMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.body)
                        .foregroundStyle(chatInput.isEmpty ? CRTColors.muted : CRTColors.title)
                        .padding(10)
                        .background(chatInput.isEmpty ? CRTColors.border.opacity(0.1) : CRTColors.border.opacity(0.3))
                        .clipShape(Circle())
                }
                .disabled(chatInput.isEmpty)
                .accessibilityIdentifier("haulonautSendChatButton")
            }

            // Trade offers section
            if !tradeOffers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PENDING TRADE OFFERS")
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(CRTColors.title)
                        .padding(.top, 8)

                    ForEach(tradeOffers) { offer in
                        tradeOfferRow(offer)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            await loadTradeOffers()
        }
    }

    private func sectorMessageRow(_ message: HaulonautSectorMessage) -> some View {
        let isOwnMessage = message.characterId == characterId

        return HStack(alignment: .top, spacing: 8) {
            if !isOwnMessage {
                Text(message.displayName)
                    .font(.caption.monospaced().bold())
                    .foregroundStyle(CRTColors.stat)
            }

            Text(message.message)
                .font(.caption.monospaced())
                .foregroundStyle(isOwnMessage ? CRTColors.tagline : CRTColors.description)

            Spacer()

            Text(formatMessageTime(message.timestamp))
                .font(.caption2.monospaced())
                .foregroundStyle(CRTColors.muted)
        }
        .padding(.horizontal, 8)
    }

    private func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func tradeOfferRow(_ offer: HaulonautTradeOfferSummary) -> some View {
        let isIncoming = offer.toGameUserId == characterId

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: isIncoming ? "arrow.down.circle" : "arrow.up.circle")
                    .foregroundStyle(isIncoming ? CRTColors.stat : CRTColors.muted)

                Text(isIncoming ? "From \(offer.fromDisplayName)" : "To \(offer.toDisplayName)")
                    .font(.caption.monospaced())
                    .foregroundStyle(CRTColors.tagline)

                Spacer()
            }

            Text("\(offer.quantity)x \(offer.itemName) for \(offer.credits) tokens")
                .font(.caption.monospaced())
                .foregroundStyle(CRTColors.description)

            if isIncoming {
                HStack(spacing: 8) {
                    Button {
                        Task { await acceptTradeOffer(offer) }
                    } label: {
                        Text("Accept")
                            .font(.caption.monospaced().bold())
                            .foregroundStyle(CRTColors.background)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(CRTColors.stat)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .accessibilityIdentifier("haulonautAcceptTrade_\(offer.id)")

                    Button {
                        Task { await declineTradeOffer(offer) }
                    } label: {
                        Text("Decline")
                            .font(.caption.monospaced().bold())
                            .foregroundStyle(CRTColors.error)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(CRTColors.border.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .accessibilityIdentifier("haulonautDeclineTrade_\(offer.id)")
                }
            }
        }
        .padding()
        .background(CRTColors.border.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Planet Docking Actions

    private func dockAtPlanet() async {
        guard planetFeature != nil else { return }

        HaulonautSoundService.play(.descent)

        do {
            let response = try await GamesAPIService.dock(characterId: characterId)
            dockedFeatureId = response.dockedFeatureId
            cycles = response.cycles
            cyclesUpdatedAt = response.cyclesUpdatedAt
            viewportMode = .docked
            HaulonautSoundService.play(.dock)
            showSnackbar("Landed on \(planetFeature?.name ?? "planet").")
        } catch {
            HaulonautSoundService.play(.error)
            showSnackbar(error.localizedDescription)
        }
    }

    private func launchShip() async {
        do {
            let response = try await GamesAPIService.launch(characterId: characterId)
            if response.success {
                dockedFeatureId = nil
                onSurface = false
                surfaceMap = nil
                viewportMode = .space
                HaulonautSoundService.play(.launch)
                showSnackbar("Launched back into space.")
            } else {
                HaulonautSoundService.play(.error)
                showSnackbar(response.message ?? "Failed to launch.")
            }
        } catch {
            HaulonautSoundService.play(.error)
            showSnackbar(error.localizedDescription)
        }
    }

    private func exitCraft() async {
        do {
            let response = try await GamesAPIService.exitCraft(characterId: characterId)
            dockedFeatureId = response.dockedFeatureId
            surfaceMap = response.surfaceMap
            cycles = response.cycles
            cyclesUpdatedAt = response.cyclesUpdatedAt
            onSurface = true
            viewportMode = .surface
            surfaceNarration = nil
            HaulonautSoundService.play(.entry)
            showSnackbar("Stepped onto the surface.")
        } catch {
            HaulonautSoundService.play(.error)
            showSnackbar(error.localizedDescription)
        }
    }

    private func returnToShip() async {
        do {
            let response = try await GamesAPIService.returnToShip(characterId: characterId)
            if response.success {
                onSurface = false
                viewportMode = .docked
                surfaceNarration = nil
                HaulonautSoundService.play(.entry)
                showSnackbar("Returned to ship.")
            } else {
                HaulonautSoundService.play(.error)
                showSnackbar(response.message ?? "Failed to return to ship.")
            }
        } catch {
            HaulonautSoundService.play(.error)
            showSnackbar(error.localizedDescription)
        }
    }

    private func driveBuggy(_ direction: String) async {
        guard currentCycles > 0 else {
            HaulonautSoundService.play(.error)
            showSnackbar("No cycles remaining. Wait for replenishment.")
            return
        }

        HaulonautSoundService.play(.buggyMove)

        do {
            let response = try await GamesAPIService.driveBuggy(characterId: characterId, direction: direction)

            // Update surface map
            if let map = surfaceMap {
                surfaceMap = HaulonautSurfaceMap(
                    gridWidth: map.gridWidth,
                    gridHeight: map.gridHeight,
                    shipX: map.shipX,
                    shipY: map.shipY,
                    buggyX: response.buggyX,
                    buggyY: response.buggyY,
                    revealed: response.revealed
                )
            }

            cycles = response.cycles
            cyclesUpdatedAt = response.cyclesUpdatedAt

            // Update resources if effects were applied
            if let newCredits = response.credits {
                credits = newCredits
            }
            if let newRations = response.rations {
                rations = newRations
            }
            if let newFuel = response.fuel {
                fuel = newFuel
            }

            // Show narration if present
            if let narration = response.narration {
                surfaceNarration = narration
                HaulonautSoundService.play(.landingEvent)
            }

            // Check if at ship
            if response.atShip {
                showSnackbar("You're back at the ship.")
            }
        } catch {
            HaulonautSoundService.play(.error)
            showSnackbar(error.localizedDescription)
        }
    }

    // MARK: - Player Interaction Actions

    private func giveTokens(to player: HaulonautPlayerHere) async {
        // For now, give a fixed amount (10 tokens). A full implementation would show an input sheet.
        let amount = 10

        guard credits >= amount else {
            showSnackbar("Not enough tokens to give.")
            return
        }

        do {
            let response = try await GamesAPIService.giveCredits(
                characterId: characterId,
                toCharacterId: player.id,
                credits: amount
            )
            if let newCredits = response.credits {
                credits = newCredits
            }
            showSnackbar(response.message ?? "Gave \(amount) tokens to \(player.displayName).")
        } catch {
            showSnackbar(error.localizedDescription)
        }
    }

    private func attackPlayer(_ player: HaulonautPlayerHere) async {
        guard currentCycles > 0 else {
            HaulonautSoundService.play(.error)
            showSnackbar("No cycles remaining. Wait for replenishment.")
            return
        }

        HaulonautSoundService.play(.danger)

        do {
            let response = try await GamesAPIService.attack(
                characterId: characterId,
                toCharacterId: player.id
            )

            // Update cycles if returned
            if let newCycles = response.cycles, let newUpdatedAt = response.cyclesUpdatedAt {
                cycles = newCycles
                cyclesUpdatedAt = newUpdatedAt
            }

            if let damage = response.damage {
                HaulonautSoundService.play(.hit)
                if response.died {
                    HaulonautSoundService.play(.death)
                    showSnackbar("DESTROYED: \(player.displayName) dealt \(damage) damage!")
                } else {
                    HaulonautSoundService.play(.damage)
                    showSnackbar("Hit \(player.displayName) for \(damage) damage. Target HP: \(response.targetHealth ?? 0)")
                }
            } else {
                HaulonautSoundService.play(.error)
                showSnackbar(response.message ?? "Attack failed.")
            }
        } catch {
            HaulonautSoundService.play(.error)
            showSnackbar(error.localizedDescription)
        }
    }

    // MARK: - Chat Actions

    private func sendChatMessage() {
        let text = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        chatInput = ""

        // Add local echo immediately
        let localMessage = HaulonautSectorMessage(
            characterId: characterId,
            displayName: character?.displayName ?? "You",
            message: text
        )
        sectorMessages.append(localMessage)

        // Check for slash command
        if text.hasPrefix("/") {
            Task {
                await handleSlashCommand(String(text.dropFirst()))
            }
            return
        }

        // TODO: Send via Socket.IO when implemented
        // SocketManager.shared.sendSectorMessage(characterId: characterId, message: text)
        HaulonautSoundService.play(.click)
    }

    private func handleSlashCommand(_ command: String) async {
        let parts = command.split(separator: " ", maxSplits: 1)
        let cmd = parts.first.map { String($0).lowercased() } ?? ""
        let args = parts.count > 1 ? String(parts[1]) : ""

        switch cmd {
        case "help":
            showHelpMessage()
        case "give":
            await handleGiveCommand(args)
        case "offer":
            await handleOfferCommand(args)
        case "accept":
            await handleAcceptCommand(args)
        case "decline":
            await handleDeclineCommand(args)
        case "attack":
            await handleAttackCommand(args)
        case "warp":
            await handleWarpCommand(args)
        default:
            addSystemMessage("Unknown command: /\(cmd). Type /help for available commands.")
            HaulonautSoundService.play(.error)
        }
    }

    private func addSystemMessage(_ text: String) {
        let systemMessage = HaulonautSectorMessage(
            characterId: 0,
            displayName: "SYSTEM",
            message: text
        )
        sectorMessages.append(systemMessage)
    }

    private func showHelpMessage() {
        HaulonautSoundService.play(.notify)
        addSystemMessage("""
            Available commands:
            /help - Show this message
            /give <pilot> <amount> - Give tokens to a pilot
            /offer <pilot> <item> <qty> for <credits> - Propose trade
            /accept <id> - Accept a trade offer
            /decline <id> - Decline a trade offer
            /attack <pilot> - Attack a pilot
            /warp <sector#> - Warp to connected sector
            """)
    }

    private func handleGiveCommand(_ args: String) async {
        // Parse: <pilot_name> <amount>
        let parts = args.split(separator: " ")
        guard parts.count >= 2,
              let amount = Int(parts.last!) else {
            addSystemMessage("Usage: /give <pilot> <amount>")
            HaulonautSoundService.play(.error)
            return
        }

        let pilotName = parts.dropLast().joined(separator: " ")
        guard let player = playersHere.first(where: {
            $0.displayName.lowercased() == pilotName.lowercased()
        }) else {
            addSystemMessage("Pilot '\(pilotName)' not found in sector.")
            HaulonautSoundService.play(.error)
            return
        }

        guard !player.isNpc else {
            addSystemMessage("Cannot give tokens to NPCs.")
            HaulonautSoundService.play(.error)
            return
        }

        guard credits >= amount else {
            addSystemMessage("Not enough tokens. You have \(credits).")
            HaulonautSoundService.play(.error)
            return
        }

        do {
            let response = try await GamesAPIService.giveCredits(
                characterId: characterId,
                toCharacterId: player.id,
                credits: amount
            )
            if let newCredits = response.credits {
                credits = newCredits
            }
            addSystemMessage(response.message ?? "Gave \(amount) tokens to \(player.displayName).")
            HaulonautSoundService.play(.success)
        } catch {
            addSystemMessage("Error: \(error.localizedDescription)")
            HaulonautSoundService.play(.error)
        }
    }

    private func handleOfferCommand(_ args: String) async {
        // Parse: <pilot> <item_key> <qty> for <credits>
        // Example: /offer Alice fuel_cell 5 for 100
        guard let forRange = args.range(of: " for ", options: .caseInsensitive) else {
            addSystemMessage("Usage: /offer <pilot> <item> <qty> for <credits>")
            HaulonautSoundService.play(.error)
            return
        }

        let beforeFor = String(args[..<forRange.lowerBound])
        let afterFor = String(args[forRange.upperBound...]).trimmingCharacters(in: .whitespaces)

        guard let offerCredits = Int(afterFor) else {
            addSystemMessage("Invalid credits amount: '\(afterFor)'")
            HaulonautSoundService.play(.error)
            return
        }

        let beforeParts = beforeFor.split(separator: " ")
        guard beforeParts.count >= 3,
              let quantity = Int(beforeParts.last!) else {
            addSystemMessage("Usage: /offer <pilot> <item> <qty> for <credits>")
            HaulonautSoundService.play(.error)
            return
        }

        let itemKey = String(beforeParts[beforeParts.count - 2])
        let pilotName = beforeParts.dropLast(2).joined(separator: " ")

        guard let player = playersHere.first(where: {
            $0.displayName.lowercased() == pilotName.lowercased()
        }) else {
            addSystemMessage("Pilot '\(pilotName)' not found in sector.")
            HaulonautSoundService.play(.error)
            return
        }

        // Check we have the item
        guard let item = inventory.first(where: { $0.itemKey == itemKey }),
              item.quantity >= quantity else {
            addSystemMessage("You don't have \(quantity)x \(itemKey).")
            HaulonautSoundService.play(.error)
            return
        }

        do {
            let response = try await GamesAPIService.createTradeOffer(
                characterId: characterId,
                toCharacterId: player.id,
                itemKey: itemKey,
                quantity: quantity,
                credits: offerCredits
            )
            addSystemMessage(response.message ?? "Trade offer sent to \(player.displayName).")
            HaulonautSoundService.play(.success)
        } catch {
            addSystemMessage("Error: \(error.localizedDescription)")
            HaulonautSoundService.play(.error)
        }
    }

    private func handleAcceptCommand(_ args: String) async {
        guard let offerId = Int(args.trimmingCharacters(in: .whitespaces)) else {
            addSystemMessage("Usage: /accept <offer_id>")
            HaulonautSoundService.play(.error)
            return
        }

        guard let offer = tradeOffers.first(where: { $0.id == offerId }) else {
            addSystemMessage("Trade offer #\(offerId) not found.")
            HaulonautSoundService.play(.error)
            return
        }

        await acceptTradeOffer(offer)
        addSystemMessage("Accepted trade offer #\(offerId).")
    }

    private func handleDeclineCommand(_ args: String) async {
        guard let offerId = Int(args.trimmingCharacters(in: .whitespaces)) else {
            addSystemMessage("Usage: /decline <offer_id>")
            HaulonautSoundService.play(.error)
            return
        }

        guard let offer = tradeOffers.first(where: { $0.id == offerId }) else {
            addSystemMessage("Trade offer #\(offerId) not found.")
            HaulonautSoundService.play(.error)
            return
        }

        await declineTradeOffer(offer)
        addSystemMessage("Declined trade offer #\(offerId).")
    }

    private func handleAttackCommand(_ args: String) async {
        let pilotName = args.trimmingCharacters(in: .whitespaces)
        guard !pilotName.isEmpty else {
            addSystemMessage("Usage: /attack <pilot>")
            HaulonautSoundService.play(.error)
            return
        }

        guard let player = playersHere.first(where: {
            $0.displayName.lowercased() == pilotName.lowercased()
        }) else {
            addSystemMessage("Pilot '\(pilotName)' not found in sector.")
            HaulonautSoundService.play(.error)
            return
        }

        await attackPlayer(player)
    }

    private func handleWarpCommand(_ args: String) async {
        guard let sectorNumber = Int(args.trimmingCharacters(in: .whitespaces)) else {
            addSystemMessage("Usage: /warp <sector_number>")
            HaulonautSoundService.play(.error)
            return
        }

        guard let sector = connectedSectors.first(where: { $0.sectorNumber == sectorNumber }) else {
            let available = connectedSectors.map { String($0.sectorNumber) }.joined(separator: ", ")
            addSystemMessage("Sector \(sectorNumber) not connected. Available: \(available)")
            HaulonautSoundService.play(.error)
            return
        }

        guard canWarp else {
            addSystemMessage("Cannot warp - fuel depleted.")
            HaulonautSoundService.play(.error)
            return
        }

        addSystemMessage("Warping to Sector \(sectorNumber)...")
        await navigate(to: sector)
    }

    // MARK: - Trade Actions

    private func loadTradeOffers() async {
        do {
            tradeOffers = try await GamesAPIService.getTradeOffers(characterId: characterId)
        } catch {
            // Non-fatal - just don't show trade offers
        }
    }

    private func acceptTradeOffer(_ offer: HaulonautTradeOfferSummary) async {
        do {
            let response = try await GamesAPIService.acceptTradeOffer(
                characterId: characterId,
                offerId: offer.id
            )
            if let newCredits = response.credits {
                credits = newCredits
            }
            inventory = response.inventory
            tradeOffers.removeAll { $0.id == offer.id }
            HaulonautSoundService.play(.tradeSuccess)
            showSnackbar(response.message ?? "Trade accepted.")
        } catch {
            HaulonautSoundService.play(.error)
            showSnackbar(error.localizedDescription)
        }
    }

    private func declineTradeOffer(_ offer: HaulonautTradeOfferSummary) async {
        do {
            _ = try await GamesAPIService.declineTradeOffer(characterId: characterId, offerId: offer.id)
            tradeOffers.removeAll { $0.id == offer.id }
            HaulonautSoundService.play(.tradeDecline)
            showSnackbar("Trade offer declined.")
        } catch {
            HaulonautSoundService.play(.error)
            showSnackbar(error.localizedDescription)
        }
    }
}

#Preview {
    NavigationStack {
        HaulonautPlayView(characterId: 1)
    }
}
