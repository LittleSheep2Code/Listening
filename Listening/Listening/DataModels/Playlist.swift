

// Playlist.swift 修改
import Foundation
import Combine

struct Playlist: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var musicIDs: [UUID]
    let createdAt: Date
    var coverImageData: Data?
    var coverSongID: UUID?
    // 添加手动模式属性，默认为关闭
    var isManualCover: Bool = false
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.musicIDs = []
        self.createdAt = Date()
        self.coverImageData = nil
        self.coverSongID = nil
        self.isManualCover = false
    }
    
    // 提供显式的CodingKeys以处理新属性
    enum CodingKeys: String, CodingKey {
        case id, name, musicIDs, createdAt, coverImageData, coverSongID, isManualCover
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        musicIDs = try container.decode([UUID].self, forKey: .musicIDs)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        coverImageData = try container.decodeIfPresent(Data.self, forKey: .coverImageData)
        coverSongID = try container.decodeIfPresent(UUID.self, forKey: .coverSongID)
        // 处理旧版本数据中缺少isManualCover字段的情况
        isManualCover = try container.decodeIfPresent(Bool.self, forKey: .isManualCover) ?? false
    }
    
    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.id == rhs.id
    }
}
