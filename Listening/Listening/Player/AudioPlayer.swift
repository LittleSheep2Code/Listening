import AVFoundation
import Combine

class AudioPlayer: NSObject, ObservableObject {
    static let shared = AudioPlayer()
    private override init() {
        super.init()
        loadVolumeSettings()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Setting up audio session failed: \(error)")
        }
    }
    
    var player: AVAudioPlayer?
    @Published var currentPlayingID: UUID? = nil
    @Published var isPlaying = false
    @Published var isSeeking: Bool = false // 是否正在拖动进度条
    
    // 新增：自定义音量控制相关属性
    @Published var customVolume: Double = 0.7 {
        didSet {
            saveVolumeSettings()
            updatePlayerVolume()
        }
    }
    
    // 新属性：跟踪实际播放的音频ID
    private var nowPlayingID: UUID? = nil
    @Published var totalDuration: TimeInterval = 0 // 存储总时长
    
    // 播放模式
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
    
    enum PlayerAction {
        case prepare  // 只加载不播放
        case play     // 加载并播放
    }
    
    @Published var currentAction: PlayerAction = .play // 默认行为是播放
    
    @Published var playbackMode: PlaybackMode = .loopAll
    
    // 播放列表管理
    private var playlistManager: PlaybackPlaylistManager {
        PlaybackPlaylistManager.shared
    }
    
    // MARK: - 音量控制方法
    private func loadVolumeSettings() {
        if let savedVolume = UserDefaults.standard.object(forKey: "customVolume") as? Double {
            customVolume = savedVolume
        } else {
            // 默认音量 70%
            customVolume = 0.7
        }
    }
    
    private func saveVolumeSettings() {
        UserDefaults.standard.set(customVolume, forKey: "customVolume")
    }
    
    private func updatePlayerVolume() {
        player?.volume = Float(customVolume) * Float(AVAudioSession.sharedInstance().outputVolume)
    }
    
    // 添加系统音量监听
    func startObservingSystemVolume() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemVolumeChanged),
            name: NSNotification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil
        )
    }
    
    @objc private func systemVolumeChanged() {
        updatePlayerVolume()
    }
    
    // MARK: - 播放控制方法
    private func loadMusic(_ music: MusicFile) -> Bool {
        // 检查是否需要重新加载
        guard nowPlayingID != music.id || player == nil else {
            return true
        }
        
        guard let url = GlobalMusicManager.shared.fileURL(for: music.fileName) else {
            return false
        }
        
        stop()
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.delegate = PlayerDelegate(player: self)
            updatePlayerVolume() // 设置初始音量
            nowPlayingID = music.id
            currentPlayingID = music.id
            totalDuration = player?.duration ?? 0
            return true
        } catch {
            print("加载失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // 分离后的播放方法
    func play(music: MusicFile) {
        prepareOrPlay(music: music, action: .play)
    }
    
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        nowPlayingID = nil      // 清除实际播放ID
        currentPlayingID = nil  // 清除选中ID
        totalDuration = 0
        
        // 停止监听系统音量
       // NotificationCenter.default.removeObserver(self)
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
    
    // 播放下一首
    func playNextTrack() {
        guard let currentID = currentPlayingID else { return }
        playlistManager.playNextTrack(currentID: currentID, mode: playbackMode, audioPlayer: self)
    }
    
    // 播放上一首
    func playPreviousTrack() {
        guard let currentID = currentPlayingID else { return }
        playlistManager.playPreviousTrack(currentID: currentID, audioPlayer: self)
    }
    
    // 切换播放模式
    func cyclePlaybackMode() {
        let allModes = PlaybackMode.allCases
        if let currentIndex = allModes.firstIndex(of: playbackMode) {
            let nextIndex = (currentIndex + 1) % allModes.count
            playbackMode = allModes[nextIndex]
        }
    }
    
    // 处理播放结束事件
    func handleEnded() {
        guard playbackMode != .loopOne else {
            // 单曲循环，重新播放当前歌曲
            player?.currentTime = 0
            player?.play()
            return
        }
        
        playNextTrack()
    }
    
    // 跳转到指定时间（用于进度条拖拽）
    func seek(to progress: Double) {
        guard let player = player else { return }
        let newTime = min(progress * player.duration, player.duration - 0.1) // 确保不超过总时长
        player.currentTime = newTime
        
        // 如果当前是暂停状态，拖动后可能会重新准备播放，这里我们保持状态
        if !player.isPlaying {
            player.play() // 使用播放确保音频正确准备
            player.pause() // 立即暂停
        }
    }
    
    // 播放列表代理
    private class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
        weak var player: AudioPlayer?
        
        init(player: AudioPlayer) {
            self.player = player
        }
        
        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            if flag {
                self.player?.handleEnded()
            }
        }
    }
    
    // 在 AudioPlayer 中添加此方法
    func pause() {
        guard let player = player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
        }
    }
    
    // 添加专门的加载但不播放功能
    // 在 AudioPlayer 类中添加/修改
    func loadWithoutPlaying(music: MusicFile) {
        prepareOrPlay(music: music, action: .prepare)
    }
    
    func play() {
        guard let player = player,
              let currentID = currentPlayingID,
              player.isPlaying == false,
              nowPlayingID == currentID else { return }
        
        player.play()
        isPlaying = true
    }
    
    func prepareOrPlay(music: MusicFile, action: PlayerAction = .play) {
        currentAction = action
        guard let url = GlobalMusicManager.shared.fileURL(for: music.fileName) else { return }
        
        // 如果是同一首歌曲且已加载，只需更新播放状态
        if nowPlayingID == music.id && player != nil {
            if action == .play && !player!.isPlaying {
                player?.play()
                isPlaying = true
            }
            updatePlayerVolume() // 确保音量更新
            return
        }
        
        stop() // 停止当前播放
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.delegate = PlayerDelegate(player: self)
            player?.volume = Float(customVolume) * Float(AVAudioSession.sharedInstance().outputVolume)
            
            nowPlayingID = music.id
            currentPlayingID = music.id
            totalDuration = player?.duration ?? 0
            
            // 只在需要播放时才启动播放
            if action == .play {
                player?.play()
                isPlaying = true
            } else {
                isPlaying = false
            }
            
            // 开启音量监听
            startObservingSystemVolume()
            
        } catch {
            print("操作失败: \(error.localizedDescription)")
        }
    }
}
