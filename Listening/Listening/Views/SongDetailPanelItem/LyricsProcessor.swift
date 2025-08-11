import Foundation
import Combine

class LyricsProcessor {
    private var currentTask: DispatchWorkItem?
    
    func processLyricsFile(for musicID: UUID, 
                           content: String, 
                           completion: @escaping ([LyricLine]) -> Void) {
        // 取消之前的任务
        cancelProcessing()
        
        let task = DispatchWorkItem { 
            // 解析歌词（同步）
            let parsedLines = LyricsParser.parse(content)
            DispatchQueue.main.async {
                completion(parsedLines)
            }
        }
        
        currentTask = task
        
        // 延迟0.1秒执行
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1, execute: task)
    }
    
    func cancelProcessing() {
        currentTask?.cancel()
        currentTask = nil
    }
}

// 歌词解析器




class LyricsParser {
    // 简单的基于字符串分割的解析器（兼容 Swift Playgrounds）
    static func parse(_ text: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        
        text.enumerateLines { line, _ in
            // 支持格式: [00:00.000] 歌词文本
            guard line.contains("[") && line.contains("]") else { return }
            
            // 找到时间部分和文本部分
            let components = line.split(separator: "]")
            guard components.count >= 2 else { return }
            
            // 1. 解析时间部分
            let timePart = components[0].replacingOccurrences(of: "[", with: "")
            if let time = parseTime(timePart) {
                // 2. 组合歌词文本部分（可能有多段]
                let textPart = components.dropFirst().joined(separator: "]")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !textPart.isEmpty {
                    lines.append(LyricLine(text: textPart, startTime: time))
                }
            }
        }
        
        return lines.sorted { $0.startTime < $1.startTime }
    }
    
    // 手动解析时间格式
    private static func parseTime(_ timeString: String) -> TimeInterval? {
        let components = timeString.split(separator: ":")
        guard components.count == 2 else { return nil }
        
        // 提取分钟
        guard let minutes = Double(components[0]) else { return nil }
        
        // 提取秒（可能包含毫秒）
        let secondsPart = components[1]
        let secondsComponents = secondsPart.split(separator: ".")
        
        var totalSeconds: TimeInterval = 0
        
        // 处理纯秒格式 [00:00]
        if secondsComponents.count == 1, let seconds = Double(secondsComponents[0]) {
            totalSeconds = minutes * 60 + seconds
        }
        // 处理毫秒格式 [00:00.000]
        else if secondsComponents.count == 2 {
            // 解析秒
            guard let seconds = Double(secondsComponents[0]) else { return nil }
            
            // 正常化毫秒值
            let msString = String(secondsComponents[1].prefix(3))
            var milliseconds = 0.0
            
            if msString.count == 1 {
                milliseconds = Double(msString)! * 100 // 0.1 -> 100ms
            } else if msString.count == 2 {
                milliseconds = Double(msString)! * 10  // 0.01 -> 10ms
            } else if msString.count == 3 {
                milliseconds = Double(msString)!
            }
            
            totalSeconds = minutes * 60 + seconds + (milliseconds / 1000.0)
        } else {
            return nil
        }
        
        return totalSeconds
    }
}
