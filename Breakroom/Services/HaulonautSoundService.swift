import AVFoundation

/// Sound service for Haulonaut game - plays SFX and ambient audio.
@MainActor
enum HaulonautSoundService {
    // MARK: - Sound Keys

    enum SFX: String, CaseIterable {
        // UI cues
        case click = "ui-click"
        case open = "ui-open"
        case success = "ui-success"
        case error = "ui-error"

        // Navigation + Combat
        case warp
        case drift
        case arrival
        case presence
        case hit
        case damage
        case danger
        case death

        // Trade/Hail + Landing/Launch/Docking
        case notify
        case tradeSuccess = "trade-success"
        case tradeDecline = "trade-decline"
        case descent
        case entry
        case dock
        case launch

        // Surface exploration
        case buggyMove = "buggy-move"
        case npcPresence = "npc-presence"
        case landingEvent = "landing-event"
    }

    enum Ambient: String, CaseIterable {
        case space = "amb-space"
        case outpost = "amb-outpost"
        case surface = "amb-surface"
    }

    // MARK: - State

    private static var sfxPlayers: [String: AVAudioPlayer] = [:]
    private static var ambientPlayer: AVAudioPlayer?
    private static var currentAmbient: Ambient?

    // MARK: - UserDefaults Keys

    private static let mutedKey = "HaulonautSoundMuted"
    private static let volumeKey = "HaulonautSoundVolume"

    // MARK: - Public API

    /// Whether all sounds are muted.
    static var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: mutedKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: mutedKey)
            if newValue {
                stopAmbient()
            } else if let current = currentAmbient {
                playAmbient(current)
            }
        }
    }

    /// Master volume (0.0 - 1.0). Defaults to 0.7.
    static var volume: Float {
        get {
            let stored = UserDefaults.standard.float(forKey: volumeKey)
            return stored > 0 ? stored : 0.7
        }
        set {
            UserDefaults.standard.set(max(0, min(1, newValue)), forKey: volumeKey)
            ambientPlayer?.volume = newValue * 0.4  // Ambient is quieter
        }
    }

    /// Play a one-shot sound effect.
    static func play(_ sound: SFX) {
        guard !isMuted else { return }

        guard let url = Bundle.main.url(
            forResource: sound.rawValue,
            withExtension: "wav",
            subdirectory: "Sounds/Haulonaut"
        ) else {
            print("[HaulonautSound] Missing sound file: \(sound.rawValue).wav")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.prepareToPlay()
            player.play()

            // Store reference to prevent deallocation
            sfxPlayers[sound.rawValue] = player
        } catch {
            print("[HaulonautSound] Error playing \(sound.rawValue): \(error.localizedDescription)")
        }
    }

    /// Start looping an ambient track. Pass nil to stop ambient audio.
    static func playAmbient(_ ambient: Ambient?) {
        guard let ambient = ambient else {
            stopAmbient()
            return
        }

        // Don't restart if already playing this ambient
        if currentAmbient == ambient, ambientPlayer?.isPlaying == true {
            return
        }

        guard !isMuted else {
            currentAmbient = ambient
            return
        }

        guard let url = Bundle.main.url(
            forResource: ambient.rawValue,
            withExtension: "wav",
            subdirectory: "Sounds/Haulonaut"
        ) else {
            print("[HaulonautSound] Missing ambient file: \(ambient.rawValue).wav")
            return
        }

        do {
            stopAmbient()

            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume * 0.4  // Ambient is quieter than SFX
            player.numberOfLoops = -1  // Loop indefinitely
            player.prepareToPlay()
            player.play()

            ambientPlayer = player
            currentAmbient = ambient
        } catch {
            print("[HaulonautSound] Error playing ambient \(ambient.rawValue): \(error.localizedDescription)")
        }
    }

    /// Stop any currently playing ambient audio.
    static func stopAmbient() {
        ambientPlayer?.stop()
        ambientPlayer = nil
    }

    /// Configure audio session for game audio (allows mixing with other audio).
    static func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[HaulonautSound] Audio session error: \(error.localizedDescription)")
        }
    }

    /// Clean up SFX player references that have finished playing.
    static func cleanupFinishedPlayers() {
        sfxPlayers = sfxPlayers.filter { $0.value.isPlaying }
    }
}
