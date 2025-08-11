import Foundation
import AVFoundation // 添加AVFoundation用于处理元数据
import UIKit // 添加UIKit用于UIImage

class GlobalMusicManager: ObservableObject {
    static let shared = GlobalMusicManager()
    
    @Published var musicFiles: [MusicFile] = []
    private let indexFileName = "global_music_index.json"
    
    var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var indexFileURL: URL {
        documentsDirectory.appendingPathComponent(indexFileName)
    }
    
    private let lyricMappingFileName = "lyrics_mapping.json"
    
    private init() {
        loadGlobalIndex()
        loadLyricMappings() // 加载歌词映射
    }
    
    // 加载全局索引
    private func loadGlobalIndex() {
        guard FileManager.default.fileExists(atPath: indexFileURL.path) else {
            print("全局索引文件不存在，创建新索引")
            return syncWithFileSystem()
        }
        
        do {
            let data = try Data(contentsOf: indexFileURL)
            musicFiles = try JSONDecoder().decode([MusicFile].self, from: data)
            print("成功加载 \(musicFiles.count) 条全局音乐记录")
        } catch {
            print("解析全局索引失败: \(error.localizedDescription)")
            syncWithFileSystem()
        }
    }
    
    // 保存到全局JSON文件
    private func saveGlobalIndex() {
        do {
            let data = try JSONEncoder().encode(musicFiles)
            try data.write(to: indexFileURL, options: [.atomicWrite])
            print("全局索引已保存")
        } catch {
            print("保存全局索引失败: \(error.localizedDescription)")
        }
    }
    
    // 同步文件系统与全局索引
    func syncWithFileSystem() {
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let allFiles = (try? fileManager.contentsOfDirectory(atPath: self.documentsDirectory.path)) ?? []
            
            // 过滤音频文件
            let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac"]
            let audioFiles = allFiles.filter { file in
                audioExtensions.contains(where: file.lowercased().hasSuffix)
            }
            
            // 处理现有索引
            var validFiles = self.musicFiles.filter { audioFiles.contains($0.fileName) }
            
            // 添加新文件到索引
            for fileName in audioFiles {
                if !validFiles.contains(where: { $0.fileName == fileName }) {
                    validFiles.append(MusicFile(fileName: fileName))
                    print("添加新文件到全局索引: \(fileName)")
                }
            }
            
            DispatchQueue.main.async {
                self.musicFiles = validFiles
                self.saveGlobalIndex()
                self.matchLyricFiles()
                print("全局索引同步完成")
            }
        }
    }
    
    // 获取音乐文件URL
    func fileURL(for fileName: String) -> URL? {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    // 全局删除音乐
    func removeMusicFile(_ music: MusicFile) {
        if let index = musicFiles.firstIndex(of: music) {
            removeMusicFile(at: index)
        }
    }
    
    private func removeMusicFile(at index: Int) {
        let file = musicFiles.remove(at: index)
        deleteFile(fileName: file.fileName)
        saveGlobalIndex()
        
        // 通知所有歌单更新
        PlaylistManager.shared.removeMusicFromAllPlaylists(file.id)
    }
    
    private func deleteFile(fileName: String) {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("文件已删除: \(fileName)")
        } catch {
            print("删除文件失败: \(error.localizedDescription)")
        }
    }
    
    // 导入音乐文件
    func importMusicFiles(_ urls: [URL]) {
        var importedCount = 0
        var processedCount = 0
        let totalCount = urls.count
        
        for url in urls {
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    throw NSError(domain: "FileAccess", code: 403, userInfo: [NSLocalizedDescriptionKey: "无法访问文件权限"])
                }
                defer { url.stopAccessingSecurityScopedResource() }
                
                let fileName = url.lastPathComponent
                let destination = documentsDirectory.appendingPathComponent(fileName)
                
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                
                try FileManager.default.copyItem(at: url, to: destination)
                
                // 提取元数据（同步版本）
                let (title, artist, duration) = extractMetadataSynchronously(from: destination)
                
                // 添加到全局索引
                if !musicFiles.contains(where: { $0.fileName == fileName }) {
                    var newMusic = MusicFile(
                        fileName: fileName,
                        title: title,
                        artist: artist
                    )
                    newMusic.duration = duration  // 设置时长
                    musicFiles.append(newMusic)
                    importedCount += 1
                }
                
                
                
                processedCount += 1
                print("导入 (\(processedCount)/\(totalCount)): \(fileName)")
            } catch {
                print("导入失败: \(url.lastPathComponent) - \(error.localizedDescription)")
            }
        }
        
        if importedCount > 0 {
            saveGlobalIndex()
            syncWithFileSystem()
        }
    }
    
    // 获取音乐文件
    func getMusic(by id: UUID) -> MusicFile? {
        musicFiles.first { $0.id == id }
    }
    
    // 获取封面图片
    // 1. 添加封面目录访问方法
    func coverPhotoDirectory() -> URL {
        let directory = documentsDirectory.appendingPathComponent(".photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                print("创建封面目录: \(directory.path)")
            } catch {
                print("创建封面目录失败: \(error)")
            }
        }
        return directory
    }
    
    // 2. 修改封面获取逻辑
    func getCoverImage(for music: MusicFile) -> UIImage? {
        // 优先加载自定义封面
        if music.hasCustomCover {
            let coverURL = coverPhotoDirectory().appendingPathComponent("\(music.id).jpg")
            if let data = try? Data(contentsOf: coverURL),
               let image = UIImage(data: data) {
                return image
            }
        }
        
        // 没有自定义封面则加载元数据封面
        guard let fileURL = fileURL(for: music.fileName) else { return nil }
        let asset = AVURLAsset(url: fileURL)
        for metadataItem in asset.metadata {
            guard metadataItem.commonKey == .commonKeyArtwork,
                  let data = metadataItem.dataValue,
                  let image = UIImage(data: data) else { continue }
            return image
        }
        
        return nil
    }
    
    // 3. 添加封面保存方法
    func saveCustomCover(for musicID: UUID, image: UIImage) -> Bool {
        guard let musicIndex = musicFiles.firstIndex(where: { $0.id == musicID }) else {
            return false
        }
        
        do {
            // 保存图片到 .photos 目录
            let coverURL = coverPhotoDirectory().appendingPathComponent("\(musicID).jpg")
            if let data = image.jpegData(compressionQuality: 0.8) {
                try data.write(to: coverURL)
                print("自定义封面保存成功: \(coverURL.lastPathComponent)")
                
                // 更新音乐文件状态
                musicFiles[musicIndex].hasCustomCover = true
                saveGlobalIndex()
                return true
            }
        } catch {
            print("保存自定义封面失败: \(error)")
        }
        return false
    }
    
    // 4. 添加封面删除方法
    func removeCustomCover(for musicID: UUID) {
        guard let musicIndex = musicFiles.firstIndex(where: { $0.id == musicID }) else {
            return
        }
        
        // 删除封面文件
        let coverURL = coverPhotoDirectory().appendingPathComponent("\(musicID).jpg")
        try? FileManager.default.removeItem(at: coverURL)
        
        // 更新状态
        musicFiles[musicIndex].hasCustomCover = false
        saveGlobalIndex()
    }
    
    // 5. 在更新元数据方法中处理封面 (移除写入文件元数据的部分)
    // 在updateMusicMetadata方法中：
    func updateMusicMetadata(for musicID: UUID, newTitle: String, newArtist: String, newCoverImage: UIImage?) {
        guard let index = musicFiles.firstIndex(where: { $0.id == musicID }),
              let fileURL = fileURL(for: musicFiles[index].fileName) else { return }
        
        // 更新内存中的元信息
        musicFiles[index].title = newTitle
        musicFiles[index].artist = newArtist
        
        // 处理自定义封面
        if let newCoverImage = newCoverImage {
            // 保存自定义封面
            _ = saveCustomCover(for: musicID, image: newCoverImage)
        } else {
            // 删除现有自定义封面
            removeCustomCover(for: musicID)
        }
        
        // 更新音频文件元数据（标题和艺术家）
        DispatchQueue.global(qos: .userInitiated).async {
            var metadata: [AVMutableMetadataItem] = []
            
            // 标题
            let titleItem = AVMutableMetadataItem()
            titleItem.identifier = .commonIdentifierTitle
            titleItem.value = newTitle as NSString
            metadata.append(titleItem)
            
            // 艺术家
            let artistItem = AVMutableMetadataItem()
            artistItem.identifier = .commonIdentifierArtist
            artistItem.value = newArtist as NSString
            metadata.append(artistItem)
            
            // 更新音频文件元数据（不含封面）
            self.updateFileMetadata(url: fileURL, metadata: metadata)
            
            // 保存全局索引
            DispatchQueue.main.async {
                self.saveGlobalIndex()
            }
        }
    }
    
    
    
    
    // 更新文件元数据
    private func updateFileMetadata(url: URL, metadata: [AVMutableMetadataItem]) {
        // 1. 创建AVAsset并获取导出预设
        let asset = AVURLAsset(url: url)
        let preset = AVAssetExportPresetPassthrough
        
        // 2. 创建导出会话
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
            print("无法创建导出会话")
            return
        }
        
        // 3. 设置输出设置
        guard let outputURL = self.uniqueOutputURL(for: url) else {
            print("无法创建临时输出URL")
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a  // 对MP4和M4A文件有效
        exportSession.metadata = metadata
        
        // 4. 执行导出
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                print("元数据更新成功")
                // 替换原始文件
                do {
                    try FileManager.default.removeItem(at: url)
                    try FileManager.default.moveItem(at: outputURL, to: url)
                    
                    // 通知所有视图更新
                    DispatchQueue.main.async {
                        self.objectWillChange.send()
                    }
                } catch {
                    print("文件替换失败: \(error)")
                }
                
            case .failed:
                if let error = exportSession.error {
                    print("元数据更新失败: \(error.localizedDescription)")
                }
                
            case .cancelled:
                print("元数据更新已取消")
                
            default:
                break
            }
        }
    }
    
    // 创建唯一的临时输出URL
    private func uniqueOutputURL(for originalURL: URL) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let originalName = originalURL.deletingPathExtension().lastPathComponent
        let extensionName = originalURL.pathExtension
        let tempURL = tempDir.appendingPathComponent("\(originalName)_temp.\(extensionName)")
        
        // 清除可能存在的旧临时文件
        try? FileManager.default.removeItem(at: tempURL)
        
        return tempURL
    }
    
    // 元数据提取函数
    private func extractMetadataSynchronously(from fileURL: URL) -> (title: String, artist: String, duration: TimeInterval) {
        let defaultTitle = fileURL.deletingPathExtension().lastPathComponent
        let defaultArtist = "未知艺人"
        let defaultDuration: TimeInterval = 0
        
        let asset = AVURLAsset(url: fileURL)
        
        var title = defaultTitle
        var artist = defaultArtist
        let duration = CMTimeGetSeconds(asset.duration)  // 获取时长（秒）
        
        // 搜索标题和艺人的简单方法
        if let titleItem = AVMetadataItem.metadataItems(from: asset.metadata, filteredByIdentifier: .commonIdentifierTitle).first,
           let value = titleItem.stringValue, !value.isEmpty {
            title = value
        }
        
        if let artistItem = AVMetadataItem.metadataItems(from: asset.metadata, filteredByIdentifier: .commonIdentifierArtist).first,
           let value = artistItem.stringValue, !value.isEmpty {
            artist = value
        }
        
        return (title, artist, duration)
    }
    
    func fileURL(forTitle title: String, artist: String) -> URL? {
        // 确保在主线程访问 @Published 属性
        guard Thread.isMainThread else {
            var result: URL? = nil
            DispatchQueue.main.sync {
                result = fileURL(forTitle: title, artist: artist)
            }
            return result
        }
        
        // 进行大小写不敏感的模糊匹配
        if let file = musicFiles.first(where: { 
            let cleanedTitle = title.lowercased().trimmingCharacters(in: .whitespaces)
            let cleanedArtist = artist.lowercased().trimmingCharacters(in: .whitespaces)
            
            let fileTitle = $0.title.lowercased().trimmingCharacters(in: .whitespaces)
            let fileArtist = $0.artist.lowercased().trimmingCharacters(in: .whitespaces)
            
            return fileTitle.contains(cleanedTitle) && 
            fileArtist.contains(cleanedArtist)
        }) {
            return fileURL(for: file.fileName)
        }
        
        return nil
    }
    
    func getOriginalCoverImage(for music: MusicFile) -> UIImage? {
        guard let fileURL = fileURL(for: music.fileName) else { return nil }
        
        let asset = AVURLAsset(url: fileURL)
        for metadataItem in asset.metadata {
            guard metadataItem.commonKey == .commonKeyArtwork,
                  let data = metadataItem.dataValue,
                  let image = UIImage(data: data) else { continue }
            
            return image
        }
        
        return nil
    }
    
    // 格式化时间为"1h20min"格式
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h\(minutes)min"
        } else {
            return "\(minutes)min"
        }
    }
    
    // 计算歌单总时长
    func totalDuration(for musicIDs: [UUID]) -> String {
        let totalSeconds = musicIDs.reduce(0.0) { total, id in
            guard let music = getMusic(by: id), let duration = music.duration else { return total }
            return total + duration
        }
        
        return formatDuration(totalSeconds)
    }
    
    // 加载歌词映射
    private func loadLyricMappings() {
        let url = documentsDirectory.appendingPathComponent(lyricMappingFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let mappings = try JSONDecoder().decode([UUID: String].self, from: data)
            
            // 更新musicFiles中的歌词文件关联
            for (musicID, lyricFileName) in mappings {
                if let index = musicFiles.firstIndex(where: { $0.id == musicID }) {
                    musicFiles[index].lyricFileName = lyricFileName
                }
            }
        } catch {
            print("加载歌词映射失败: \(error)")
        }
    }
    
    // 保存歌词映射
    private func saveLyricMappings() {
        let url = documentsDirectory.appendingPathComponent(lyricMappingFileName)
        var mappings = [UUID: String]()
        
        // 创建音乐ID到歌词文件名的映射
        for music in musicFiles {
            if let lyricFileName = music.lyricFileName {
                mappings[music.id] = lyricFileName
            }
        }
        
        do {
            let data = try JSONEncoder().encode(mappings)
            try data.write(to: url, options: [.atomicWrite])
            print("歌词映射已保存")
        } catch {
            print("保存歌词映射失败: \(error)")
        }
    }
    
    // 同步时查找匹配的歌词文件
    func matchLyricFiles() {
        var mappingsUpdated = false
        
        // 获取所有歌词文件
        let allFiles = (try? FileManager.default.contentsOfDirectory(atPath: documentsDirectory.path)) ?? []
        let lyricFiles = allFiles.filter { $0.lowercased().hasSuffix(".lrc") }
        
        for index in musicFiles.indices {
            let music = musicFiles[index]
            
            // 如果已有歌词文件，检查文件是否存在
            if let existingLyric = music.lyricFileName {
                let filePath = documentsDirectory.appendingPathComponent(existingLyric).path
                if !FileManager.default.fileExists(atPath: filePath) {
                    musicFiles[index].lyricFileName = nil
                    mappingsUpdated = true
                    print("歌词文件不存在: \(existingLyric)，已移除关联")
                }
                continue
            }
            
            // 尝试匹配新的歌词文件
            let musicName = (music.fileName as NSString).deletingPathExtension
            
            // 策略1: 匹配与歌曲文件名完全相同的歌词文件
            let exactMatch = lyricFiles.first { 
                $0.lowercased() == "\(musicName).lrc".lowercased() 
            }
            
            // 策略2: 匹配包含歌曲标题的歌词文件
            let titleMatch = exactMatch ?? lyricFiles.first {
                !music.title.isEmpty && $0.lowercased().contains(music.title.lowercased())
            }
            
            // 策略3: 匹配包含艺术家+标题的歌词文件
            let artistTitleMatch = titleMatch ?? lyricFiles.first {
                !music.artist.isEmpty && 
                !music.title.isEmpty &&
                $0.lowercased().contains("\(music.artist) - \(music.title)".lowercased())
            }
            
            if let matchedLyric = artistTitleMatch {
                musicFiles[index].lyricFileName = matchedLyric
                mappingsUpdated = true
                print("为音乐 \(music.title) 匹配到歌词: \(matchedLyric)")
            }
        }
        
        if mappingsUpdated {
            saveLyricMappings()
            self.objectWillChange.send() // 通知视图更新
        }
    }
    
    // 导入歌词文件
    func importLyricFile(url: URL, forMusic musicID: UUID) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "FileAccess", code: 403, userInfo: [NSLocalizedDescriptionKey: "无法访问文件权限"])
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let fileName = url.lastPathComponent
            let destination = documentsDirectory.appendingPathComponent(fileName)
            
            // 确保是.lrc文件
            guard fileName.lowercased().hasSuffix(".lrc") else {
                print("导入失败: 仅支持 .lrc 格式的歌词文件")
                return
            }
            
            // 复制文件
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: url, to: destination)
            
            // 关联到音乐
            if let index = musicFiles.firstIndex(where: { $0.id == musicID }) {
                musicFiles[index].lyricFileName = fileName
                saveLyricMappings()
                self.objectWillChange.send()
                print("歌词文件关联成功: \(fileName) -> \(musicFiles[index].title)")
            }
        } catch {
            print("导入歌词文件失败: \(error.localizedDescription)")
        }
    }
    
    // 删除关联的歌词文件
    func removeLyricFile(forMusic musicID: UUID) {
        guard let index = musicFiles.firstIndex(where: { $0.id == musicID }) else { return }
        
        // 只删除关联，不删除物理文件
        musicFiles[index].lyricFileName = nil
        saveLyricMappings()
        self.objectWillChange.send()
        print("已移除音乐 \(musicFiles[index].title) 的歌词关联")
    }
    
    // 获取歌词内容
    func getLyrics(forMusic musicID: UUID) -> String? {
        guard let music = getMusic(by: musicID),
              let lyricURL = music.lyricFileURL(),
              FileManager.default.fileExists(atPath: lyricURL.path),
              let content = try? String(contentsOf: lyricURL, encoding: .utf8) else {
            return nil
        }
        return content
    }
}
