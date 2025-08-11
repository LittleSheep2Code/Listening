import Foundation

struct MusicFile: Identifiable, Codable, Equatable {
    let id: UUID
    let fileName: String
    var title: String
    var artist: String
    var hasCustomCover: Bool
    var duration: TimeInterval? // 时长属性（秒）
    var lyricFileName: String?  // 新增：关联的歌词文件名
    
    init(fileName: String, title: String = "", artist: String = "", duration: TimeInterval? = nil, lyricFileName: String? = nil) {
        self.id = UUID()
        self.fileName = fileName
        self.title = title.isEmpty ? fileName : title
        self.artist = artist
        self.hasCustomCover = false
        self.duration = duration
        self.lyricFileName = lyricFileName
    }
    
    // 计算属性：歌词文件URL（如果存在）
    func lyricFileURL() -> URL? {
        guard let lyricFileName = lyricFileName else { return nil }
        return GlobalMusicManager.shared.documentsDirectory.appendingPathComponent(lyricFileName)
    }
}
