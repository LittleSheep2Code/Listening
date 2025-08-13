import Foundation
import Combine

class PlaybackPlaylistManager: ObservableObject {
    static let shared = PlaybackPlaylistManager()
    
    // 持久化键名
    private let playlistKey = "SavedPlaybackPlaylist"
    private let currentIdKey = "SavedCurrentPlayingID"
    private let playlistTagKey = "SavedPlaylistTag"
    
    @Published var playlistTag: String = "播放列表"
    @Published var musicFiles: [MusicFile] = []
    @Published var currentPlayingID: UUID?
    
    private var autoSaveEnabled = false
    
    private init() {
        // 初始化后加载持久化状态
        loadPersistedState()
        autoSaveEnabled = true
    }
    
    private func savePlaybackState() {
        guard autoSaveEnabled else { return }
        
        // 将UUID数组转成字符串数组保存
        let idArray = musicFiles.map { $0.id.uuidString }
        
        UserDefaults.standard.set(idArray, forKey: playlistKey)
        UserDefaults.standard.set(currentPlayingID?.uuidString, forKey: currentIdKey)
        UserDefaults.standard.set(playlistTag, forKey: playlistTagKey)
        
        print("播放状态已保存: \(idArray.count) 首歌曲")
    }
    
    private func loadPersistedState() {
        // 加载播放列表
        guard 
            let savedIDs = UserDefaults.standard.array(forKey: playlistKey) as? [String]
        else {
           // print("没有找到播放列表持久化数据")
            return
        }
        
        // 转换字符串为UUID并过滤无效项
        let musicIDs = savedIDs.compactMap { UUID(uuidString: $0) }
        
        // 获取对应的音乐文件
        var validFiles: [MusicFile] = []
        for id in musicIDs {
            if let music = GlobalMusicManager.shared.getMusic(by: id) {
                validFiles.append(music)
            } else {
                print("⚠️ 找不到对应的音乐文件: \(id)")
            }
        }
        
        // 加载当前播放ID
        var currentID: UUID?
        if let savedCurrentID = UserDefaults.standard.string(forKey: currentIdKey) {
            currentID = UUID(uuidString: savedCurrentID)
            print("加载的当前播放ID: \(currentID?.uuidString ?? "nil")")
        }
        
        // 加载播放列表标签
        let savedTag = UserDefaults.standard.string(forKey: playlistTagKey) ?? "播放列表"
        
        DispatchQueue.main.async {
            self.playlistTag = savedTag
            self.musicFiles = validFiles
            self.currentPlayingID = currentID
            
            // 尝试恢复播放状态
            self.restorePlaybackState()
            
            print("播放状态已恢复: \(validFiles.count) 首歌曲")
        }
    }
    
    // 恢复播放状态（添加自动播放功能）
    func restorePlaybackState() {
        // 首先检查播放器是否已在播放
        guard !AudioPlayer.shared.isPlaying else {
            print("播放器已在播放中，不恢复状态")
            return
        }
        
        // 检查是否有有效的当前播放ID
        guard let currentID = currentPlayingID,
              let music = musicFiles.first(where: { $0.id == currentID }) else {
            print("无有效当前播放歌曲")
            return
        }
        
        // 延迟执行确保UI已完全加载
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 再次检查播放器状态
            guard !AudioPlayer.shared.isPlaying else { return }
            
            print("恢复播放状态（加载但不播放）: \(music.title)")
            
            // 调用安全加载方法
            AudioPlayer.shared.loadWithoutPlaying(music: music)
            
            // 更新播放列表管理器的状态
            self.currentPlayingID = music.id
            self.onDataChanged()
        }
    }
    
    // 在数据变更时调用
    private func onDataChanged() {
        savePlaybackState()
    }
    
    private var currentPlaybackIndex: Int? {
        guard let id = currentPlayingID else { return nil }
        return musicFiles.firstIndex(where: { $0.id == id })
    }
    
    func loadPlaylist(fromTag tag: String, completion: (() -> Void)? = nil) {
        // 从PlaylistManager获取音乐ID列表
        let musicIDs = PlaylistManager.shared.getPlaylistContent(byTag: tag)
        
        // 获取对应的音乐文件
        let newMusicFiles = musicIDs.compactMap { id in
            GlobalMusicManager.shared.getMusic(by: id)
        }
        
        DispatchQueue.main.async {
            self.playlistTag = tag
            self.musicFiles = newMusicFiles
            self.onDataChanged()
            completion?()
        }
    }
    
    func playTrack(_ music: MusicFile) {
        // 在这里设置播放状态
        AudioPlayer.shared.play(music: music)
        currentPlayingID = music.id
        onDataChanged()
    }
    
    func stopPlayback() {
        AudioPlayer.shared.stop()
        currentPlayingID = nil
        onDataChanged()
    }
    
    func playNextTrack(currentID: UUID, mode: PlaybackMode, audioPlayer: AudioPlayer) {
        guard !musicFiles.isEmpty else { return }
        
        let nextIndex: Int
        
        switch mode {
        case .random:
            nextIndex = Int.random(in: 0..<musicFiles.count)
        default:
            guard let currentIndex = musicFiles.firstIndex(where: { $0.id == currentID }) else { return }
            nextIndex = (currentIndex + 1) % musicFiles.count
        }
        
        let nextMusic = musicFiles[nextIndex]
        audioPlayer.play(music: nextMusic)
        currentPlayingID = nextMusic.id
        onDataChanged()
    }
    
    func playPreviousTrack(currentID: UUID, audioPlayer: AudioPlayer) {
        guard !musicFiles.isEmpty else { return }
        guard let currentIndex = musicFiles.firstIndex(where: { $0.id == currentID }) else { return }
        
        let previousIndex = (currentIndex - 1 + musicFiles.count) % musicFiles.count
        let previousMusic = musicFiles[previousIndex]
        audioPlayer.play(music: previousMusic)
        currentPlayingID = previousMusic.id
        onDataChanged()
    }
    
    func clearPlaylist() {
        // 停止播放器
        if AudioPlayer.shared.isPlaying {
            AudioPlayer.shared.stop()
        }
        // 清空播放列表
        musicFiles = []
        // 重置当前播放ID
        currentPlayingID = nil
        playlistTag = "播放列表"
        onDataChanged()
    }
    
    func removeFromPlaylist(_ music: MusicFile) {
        // 找到要删除的歌曲在播放列表中的位置
        guard let index = musicFiles.firstIndex(where: { $0.id == music.id }) else { return }
        
        // 记录当前播放状态
        let wasPlaying = currentPlayingID == music.id
        
        // 从播放列表中移除歌曲
        musicFiles.remove(at: index)
        
        // 如果删除的是当前播放的歌曲
        if wasPlaying {
            // 停止播放
            currentPlayingID = nil
            
            // 如果播放列表还有歌曲，自动播放下一个合适的歌曲
            if !musicFiles.isEmpty {
                // 下一首位置：如果删除的是最后一首，则播第一首
                let nextIndex = index < musicFiles.count ? index : 0
                let nextMusic = musicFiles[nextIndex]
                AudioPlayer.shared.play(music: nextMusic)
                currentPlayingID = nextMusic.id
            }
        }
        
        onDataChanged()
    }
    
    func addMultipleToPlaylist(_ musicFilesToAdd: [MusicFile]) {
        // 添加到当前播放列表末尾
        musicFiles.append(contentsOf: musicFilesToAdd)
        onDataChanged()
    }
    
    // 新的辅助方法：检查当前是否有正在播放的音乐
    var hasActivePlayback: Bool {
        return currentPlayingID != nil && !musicFiles.isEmpty
    }
}
