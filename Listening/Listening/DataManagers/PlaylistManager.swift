import Foundation
import Combine

class PlaylistManager: ObservableObject {
    static let shared = PlaylistManager()
    
    @Published var playlists: [Playlist] = []
    private let playlistDirectory: URL
    
    // 新增发布者用于强制刷新
    @Published var playlistUpdateTrigger: Bool = false
    
    private init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        playlistDirectory = documentsDirectory.appendingPathComponent("Playlists")
        
        do {
            try FileManager.default.createDirectory(at: playlistDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("创建歌单目录失败: \(error)")
        }
        
        loadAllPlaylists()
    }
    
    // 创建播放列表文件路径
    private func fileURL(for playlist: Playlist) -> URL {
        playlistDirectory.appendingPathComponent("playlist_\(playlist.id.uuidString).json")
    }
    
    // 加载所有歌单
    private func loadAllPlaylists() {
        playlists.removeAll()
        do {
            let playlistFiles = try FileManager.default.contentsOfDirectory(atPath: playlistDirectory.path)
            for file in playlistFiles where file.hasPrefix("playlist_") && file.hasSuffix(".json") {
                let fileURL = playlistDirectory.appendingPathComponent(file)
                let data = try Data(contentsOf: fileURL)
                let playlist = try JSONDecoder().decode(Playlist.self, from: data)
                playlists.append(playlist)
            }
            print("加载 \(playlists.count) 个歌单")
            
            // 应用保存的顺序
            if let savedOrder = loadAllPlaylistsOrder() {
                var orderedPlaylists: [Playlist] = []
                for id in savedOrder {
                    if let playlist = playlists.first(where: { $0.id == id }) {
                        orderedPlaylists.append(playlist)
                    }
                }
                // 添加未排序的歌单（新创建）
                let unorderedPlaylists = playlists.filter { !savedOrder.contains($0.id) }
                playlists = orderedPlaylists + unorderedPlaylists
            }
        } catch {
            print("加载歌单失败: \(error)")
        }
    }
    
    // 加载歌单顺序
    private func loadAllPlaylistsOrder() -> [UUID]? {
        let orderFileURL = playlistDirectory.appendingPathComponent("playlists_order.json")
        guard FileManager.default.fileExists(atPath: orderFileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: orderFileURL)
            let orderedIDs = try JSONDecoder().decode([String].self, from: data)
            return orderedIDs.compactMap { UUID(uuidString: $0) }
        } catch {
            print("加载歌单顺序失败: \(error)")
            return nil
        }
    }
    
    // 保存歌单 - 关键修改：确保触发视图更新
    private func savePlaylist(_ playlist: Playlist) {
        do {
            let data = try JSONEncoder().encode(playlist)
            let fileURL = fileURL(for: playlist)
            try data.write(to: fileURL, options: [.atomicWrite])
            print("歌单保存: \(playlist.name)")
            
            // 更新内存中的列表并强制刷新
            if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
                playlists[index] = playlist
                playlistUpdateTrigger.toggle() // 强制更新
            } else {
                playlists.append(playlist)
                playlistUpdateTrigger.toggle() // 强制更新
            }
        } catch {
            print("保存歌单失败: \(error)")
        }
    }
    
    // 保存所有歌单顺序
    private func saveAllPlaylistsOrder() {
        let orderFileURL = playlistDirectory.appendingPathComponent("playlists_order.json")
        let orderedIDs = playlists.map { $0.id.uuidString }
        
        do {
            let data = try JSONEncoder().encode(orderedIDs)
            try data.write(to: orderFileURL, options: [.atomicWrite])
            print("歌单顺序已保存")
        } catch {
            print("保存歌单顺序失败: \(error)")
        }
    }
    
    // 移动歌单顺序
    func movePlaylists(from source: IndexSet, to destination: Int) {
        var reorderedPlaylists = playlists
        reorderedPlaylists.move(fromOffsets: source, toOffset: destination)
        playlists = reorderedPlaylists
        saveAllPlaylistsOrder()
    }
    
    // 更新歌单中的音乐顺序
    func updateMusicOrder(in playlist: Playlist, with musicIDs: [UUID]) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            print("更新顺序失败：找不到ID为\(playlist.id)的歌单")
            return
        }
        
        // 创建副本并更新音乐顺序
        var updatedPlaylist = playlist
        updatedPlaylist.musicIDs = musicIDs
        
        // 更新内存中的歌单
        playlists[index] = updatedPlaylist
        
        // 保存到磁盘
        savePlaylist(updatedPlaylist)
        
        print("更新歌单顺序成功：\(playlist.name) 现在有 \(musicIDs.count) 首歌曲")
    }
    
    func updateMusicOrder(in playlistId: UUID, with musicIDs: [UUID]) {
        guard let playlist = getPlaylist(by: playlistId) else {
            print("更新顺序失败：找不到ID为\(playlistId)的歌单")
            return
        }
        updateMusicOrder(in: playlist, with: musicIDs)
    }
    
    // 创建新歌单
    func createPlaylist(name: String) {
        let newPlaylist = Playlist(name: name)
        savePlaylist(newPlaylist)
    }
    
    // 删除歌单 - 关键修改：确保触发视图更新
    func deletePlaylist(_ playlist: Playlist) {
        do {
            let fileURL = fileURL(for: playlist)
            try FileManager.default.removeItem(at: fileURL)
            
            if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
                playlists.remove(at: index)
                playlistUpdateTrigger.toggle() // 强制更新
            }
            print("删除歌单: \(playlist.name)")
        } catch {
            print("删除歌单失败: \(error)")
        }
    }
    
    
    
    // 添加音乐到歌单
    func addMusicToPlaylist(_ musicID: UUID, playlist: Playlist) {
        var updatedPlaylist = playlist
        if !updatedPlaylist.musicIDs.contains(musicID) {
            updatedPlaylist.musicIDs.append(musicID)
            // 只有在非手动模式下才更新封面
            if !updatedPlaylist.isManualCover {
                updateCover(for: &updatedPlaylist, using: musicID)
            }
            savePlaylist(updatedPlaylist)
        }
    }
    
    func addMultipleMusicToPlaylist(musicIDs: [UUID], playlist: Playlist) {
        var updatedPlaylist = playlist
        let uniqueIDs = Set(musicIDs)
        let newIDs = uniqueIDs.subtracting(Set(playlist.musicIDs))
        
        if !newIDs.isEmpty {
            updatedPlaylist.musicIDs.append(contentsOf: Array(newIDs))
            // 只有在非手动模式下才更新封面
            if !updatedPlaylist.isManualCover, let lastMusicID = musicIDs.last {
                updateCover(for: &updatedPlaylist, using: lastMusicID)
            }
            savePlaylist(updatedPlaylist)
        }
    }
    
    // 从歌单移除音乐
    func removeMusicFromPlaylist(musicID: UUID, playlist: Playlist) {
        var updatedPlaylist = playlist
        if let index = updatedPlaylist.musicIDs.firstIndex(of: musicID) {
            updatedPlaylist.musicIDs.remove(at: index)
            
            // 如果删除的是封面歌曲，重置封面
            if playlist.coverSongID == musicID {
                updatedPlaylist.coverImageData = nil
                updatedPlaylist.coverSongID = nil
            }
            
            savePlaylist(updatedPlaylist)
        }
    }
    
    // 从所有歌单中移除音乐
    func removeMusicFromAllPlaylists(_ musicID: UUID) {
        for playlist in playlists {
            if playlist.musicIDs.contains(musicID) {
                var updated = playlist
                updated.musicIDs.removeAll { $0 == musicID }
                savePlaylist(updated)
            }
        }
    }
    
    // 获取歌单中的音乐
    func getMusics(for playlist: Playlist) -> [MusicFile] {
        return playlist.musicIDs.compactMap { id in
            GlobalMusicManager.shared.getMusic(by: id)
        }
    }
    
    // 通过ID获取歌单
    func getPlaylist(by id: UUID) -> Playlist? {
        playlists.first { $0.id == id }
    }
    
    // 强制更新所有视图
    func forceUpdate() {
        playlistUpdateTrigger.toggle()
    }
    
    //检查歌单名称是否已存在
    func playlistNameExists(_ name: String) -> Bool {
        // 不区分大小写比较
        return playlists.contains { playlist in
            playlist.name.lowercased() == name.lowercased()
        }
    }
    
    //通过名称获取歌单(貌似用不着)
    func getPlaylist(byName name: String) -> (name: String, musicIDs: [UUID]) {
        if name.lowercased() == "全部" {
            // 获取全部音乐文件ID（排除重复）
            let allMusicIDs = Array(Set(GlobalMusicManager.shared.musicFiles.map { $0.id }))
            return ("全部音乐", allMusicIDs)
        } else {
            // 遍历所有歌单，查找匹配的歌单
            for playlist in playlists {
                if playlist.name.lowercased() == name.lowercased() {
                    return (playlist.name, playlist.musicIDs)
                }
            }
            // 如果未找到，返回空歌单
            return (name, [])
        }
    }
    
    // MARK: - 通过歌单标签名获取歌单内容
    func getPlaylistContent(byTag tag: String) -> [UUID] {
        if tag == "全部" || tag.lowercased() == "all" {
            // 获取所有音乐文件的ID
            return GlobalMusicManager.shared.musicFiles.map { $0.id }
        } else {
            // 查找匹配的歌单并返回它的音乐ID列表
            return playlists.first { $0.name == tag }?.musicIDs ?? []
        }
    }
    
    
    
    func removeMultipleMusicFromPlaylist(musicIDs: [UUID], playlist: Playlist) {
        var updatedPlaylist = playlist
        updatedPlaylist.musicIDs.removeAll { musicIDs.contains($0) }
        savePlaylist(updatedPlaylist)
    }
    
    //更新封面
    private func updateCover(for playlist: inout Playlist, using musicID: UUID) {
        playlist.coverSongID = musicID
        
        // 获取封面图片
        if let music = GlobalMusicManager.shared.getMusic(by: musicID),
           let coverImage = GlobalMusicManager.shared.getCoverImage(for: music)?.jpegData(compressionQuality: 0.7) {
            playlist.coverImageData = coverImage
        }
    }
    
    // 更新歌单名称
    func updatePlaylistName(playlistId: UUID, newName: String) -> String? {
        guard !newName.isEmpty else { return "歌单名称不能为空" }
        
        // 检查名称是否已被其他歌单使用（排除当前歌单）
        if playlists.contains(where: { $0.id != playlistId && $0.name == newName }) {
            return "歌单名称已被使用"
        }
        
        guard var playlist = getPlaylist(by: playlistId) else {
            return "找不到歌单"
        }
        
        playlist.name = newName
        savePlaylist(playlist)
        return nil  // 返回 nil 表示成功
    }
    
    // 更新歌单封面图片
    func updatePlaylistCoverImage(playlistId: UUID, coverImageData: Data?, markManual: Bool = false) {
        guard var playlist = getPlaylist(by: playlistId) else { return }
        playlist.coverImageData = coverImageData
        // 如果标记为手动，设置手动模式为true
        if markManual {
            playlist.isManualCover = true
        }
        savePlaylist(playlist)
    }
    
    // 标记封面为手动设置
    func markCoverAsManual(for playlistId: UUID) {
        guard var playlist = getPlaylist(by: playlistId) else { return }
        playlist.isManualCover = true
        savePlaylist(playlist)
    }
    
    // 切换手动封面模式（保留原方法）
    func toggleManualCover(for playlist: Playlist) {
        var updatedPlaylist = playlist
        updatedPlaylist.isManualCover.toggle()
        savePlaylist(updatedPlaylist)
    }
}
