
import Foundation
import Combine

// 在 GlobalMusicManager.swift 或其他合适的位置添加
struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let startTime: TimeInterval // 歌词开始时间(秒)
    var duration: TimeInterval? // 歌词持续时间(可选，用于歌词高亮)
    
    init(text: String, startTime: TimeInterval) {
        self.text = text
        self.startTime = startTime
    }
}
