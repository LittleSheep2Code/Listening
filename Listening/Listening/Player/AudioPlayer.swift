import AVFoundation
import Combine
import MediaPlayer
import UIKit

// MARK: - Protocols and Enums

/// Defines the essential playback controls and state.
protocol PlaybackController: AnyObject {
    var isPlaying: Bool { get }
    var totalDuration: TimeInterval { get }
    var playbackMode: PlaybackMode { get set }
    
    func play(music: MusicFile)
    func pause()
    func togglePlayPause()
    func stop()
    func seek(to progress: Double)
    func playNextTrack()
    func playPreviousTrack()
    func cyclePlaybackMode()
}

/// Defines the essential data model for a music file.
protocol MusicFileRepresentable {
    var id: UUID { get }
    var title: String { get }
    var artist: String { get }
    var fileName: String { get }
}

enum PlaybackMode: CaseIterable {
    case loopAll
    case loopOne
    case random
    
    var systemImage: String {
        switch self {
        case .loopAll: return "repeat"
        case .loopOne: return "repeat.1"
        case .random: return "shuffle"
        }
    }
}

// MARK: - AudioPlayer Class

class AudioPlayer: NSObject, ObservableObject, PlaybackController {
    
    // MARK: - Singleton
    static let shared = AudioPlayer()
    
    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteTransportControls()
        setupNotifications()
        loadVolumeSettings()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        // Ensure remote commands are unregistered on deinit, although with a singleton this is rare.
        MPRemoteCommandCenter.shared().playCommand.removeTarget(self)
        MPRemoteCommandCenter.shared().pauseCommand.removeTarget(self)
        MPRemoteCommandCenter.shared().nextTrackCommand.removeTarget(self)
        MPRemoteCommandCenter.shared().previousTrackCommand.removeTarget(self)
    }
    
    // MARK: - Published Properties
    
    @Published var isPlaying = false
    @Published var totalDuration: TimeInterval = 0
    @Published var customVolume: Double = 0.7 {
        didSet {
            saveVolumeSettings()
            updatePlayerVolume()
        }
    }
    @Published var playbackMode: PlaybackMode = .loopAll
    @Published var currentPlayingID: UUID? = nil
    
    // Restored: isSeeking property
    @Published var isSeeking: Bool = false
    
    // MARK: - Private Properties
    
    internal var player: AVAudioPlayer?
    private var playerDelegate: PlayerDelegate?
    private var nowPlayingID: UUID? = nil
    
    private var playlistManager: PlaybackPlaylistManager {
        PlaybackPlaylistManager.shared
    }
    
    // MARK: - Setup and Lifecycle
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
        } catch {
            print("Setting up audio session failed: \(error)")
        }
    }
    
    private func setupNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleAudioSessionInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleAppDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        // Register for system volume changes
        nc.addObserver(self, selector: #selector(systemVolumeChanged), name: NSNotification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"), object: nil)
    }
    
    @objc private func handleAppDidBecomeActive() {
        print("handleAppDidBecomeActive")
        reactivateAudioSession()
        setupRemoteTransportControls()
    }
    
    private func reactivateAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(true)
            updatePlayerVolume()
            updateNowPlayingPlaybackInfo()
        } catch {
            print("Failed to reactivate audio session: \(error)")
        }
    }
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        print("handleAudioSessionInterruption")
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            if isPlaying { pause() }
        case .ended:
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            reactivateAudioSession()
            if options.contains(.shouldResume) {
                // `play()` will only resume if a song is loaded and a user expects it to play.
                play()
            }
        @unknown default:
            break
        }
    }
    
    // MARK: - Volume Control
    
    private func loadVolumeSettings() {
        customVolume = UserDefaults.standard.object(forKey: "customVolume") as? Double ?? 0.7
    }
    
    private func saveVolumeSettings() {
        UserDefaults.standard.set(customVolume, forKey: "customVolume")
    }
    
    @objc private func systemVolumeChanged() {
        print("systemVolumeChanged")
        updatePlayerVolume()
    }
    
    private func updatePlayerVolume() {
        player?.volume = Float(customVolume)
    }
    
    // MARK: - Playback Control
    
    func play(music: MusicFile) {
        // Use the new private prepareAndPlay method for consistency
        prepareAndPlay(music: music, shouldPlay: true)
    }
    
    // Restored: loadWithoutPlaying method
    func loadWithoutPlaying(music: MusicFile) {
        prepareAndPlay(music: music, shouldPlay: false)
    }

    // New internal helper method to consolidate logic
    private func prepareAndPlay(music: MusicFile, shouldPlay: Bool) {
        // If the same music is already loaded, handle accordingly
        if music.id == nowPlayingID {
            if shouldPlay {
                player?.play()
                isPlaying = true
            } else {
                // If it's the same music and we're just loading, do nothing
                return
            }
            updateNowPlayingPlaybackInfo()
            return
        }
        
        // Stop current playback and load the new music
        stop()
        
        guard let url = GlobalMusicManager.shared.fileURL(for: music.fileName) else {
            print("Failed to get URL for music file: \(music.fileName)")
            return
        }
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            playerDelegate = PlayerDelegate(player: self)
            player?.delegate = playerDelegate
            player?.prepareToPlay()
            
            // Update state
            nowPlayingID = music.id
            currentPlayingID = music.id
            totalDuration = player?.duration ?? 0
            
            // Set volume and play if needed
            updatePlayerVolume()
            
            if shouldPlay {
                player?.play()
                isPlaying = true
            } else {
                isPlaying = false
            }
            
            // Update Now Playing Info
            updateNowPlayingInfo(for: music)
            updateNowPlayingPlaybackInfo()
        } catch {
            print("Failed to load music: \(error.localizedDescription)")
            stop()
        }
    }
    
    // The `play()` method for resuming after interruptions
    func play() {
        guard let player = player, !player.isPlaying else { return }
        player.play()
        isPlaying = true
        updateNowPlayingPlaybackInfo()
    }
    
    func pause() {
        guard let player = player, player.isPlaying else { return }
        player.pause()
        isPlaying = false
        updateNowPlayingPlaybackInfo()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            // This is for resuming a paused song, not starting a new one.
            play()
        }
    }
    
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        nowPlayingID = nil
        currentPlayingID = nil
        totalDuration = 0
        
        // Clear Now Playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func playNextTrack() {
        guard let currentID = currentPlayingID else { return }
        playlistManager.playNextTrack(currentID: currentID, mode: playbackMode, audioPlayer: self)
    }
    
    func playPreviousTrack() {
        guard let currentID = currentPlayingID else { return }
        playlistManager.playPreviousTrack(currentID: currentID, audioPlayer: self)
    }
    
    func cyclePlaybackMode() {
        let allModes = PlaybackMode.allCases
        if let currentIndex = allModes.firstIndex(of: playbackMode) {
            let nextIndex = (currentIndex + 1) % allModes.count
            playbackMode = allModes[nextIndex]
        }
    }
    
    func seek(to progress: Double) {
        guard let player = player else { return }
        let newTime = player.duration * progress
        player.currentTime = newTime
        updateNowPlayingPlaybackInfo()
        
        // Preserve playback state if seeking while paused
        if !player.isPlaying && isPlaying {
            player.play() // Temporarily play to ensure seek is committed
            player.pause() // Immediately pause again
        }
    }
    
    /// Called by the delegate when playback finishes.
    func handlePlaybackEnded() {
        guard playbackMode != .loopOne else {
            player?.currentTime = 0
            player?.play()
            isPlaying = true
            updateNowPlayingPlaybackInfo()
            return
        }
        playNextTrack()
    }
    
    // MARK: - Now Playing Info
    
    private func setupRemoteTransportControls() {
        print("Setting up remote transport controls")
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget(handler: handleChangePlaybackPosition)
        
        commandCenter.playCommand.addTarget(handler: handlePlayCommand)
        commandCenter.pauseCommand.addTarget(handler: handlePauseCommand)
        commandCenter.nextTrackCommand.addTarget(handler: handleNextTrackCommand)
        commandCenter.previousTrackCommand.addTarget(handler: handlePreviousTrackCommand)
        print("Set up remote transport controls done")
    }
    
    private func handleChangePlaybackPosition(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        if isPlaying {
            seek(to: (event as! MPChangePlaybackPositionCommandEvent).positionTime / self.player!.duration)
            return .success
        }
        return .commandFailed
    }
    
    private func handlePlayCommand(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        if !isPlaying {
            play()
            return .success
        }
        return .commandFailed
    }
    
    private func handlePauseCommand(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        if isPlaying {
            pause()
            return .success
        }
        return .commandFailed
    }
    
    private func handleNextTrackCommand(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        playNextTrack()
        return .success
    }
    
    private func handlePreviousTrackCommand(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        playPreviousTrack()
        return .success
    }
    
    private func updateNowPlayingInfo(for music: MusicFile) {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: music.title,
            MPMediaItemPropertyArtist: music.artist,
            MPMediaItemPropertyPlaybackDuration: player?.duration ?? 0
        ]
        
        if let image = GlobalMusicManager.shared.getCoverImage(for: music) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingPlaybackInfo() {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}

// MARK: - AVAudioPlayerDelegate Extension

private class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
    weak var player: AudioPlayer?
    
    init(player: AudioPlayer) {
        self.player = player
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            self.player?.handlePlaybackEnded()
        }
    }
}
