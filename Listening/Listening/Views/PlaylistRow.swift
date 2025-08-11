import SwiftUI

struct PlaylistRow: View {
    let music: MusicFile
    let isPlaying: Bool
    let onTap: () -> Void
    
    // 添加删除回调
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .center) {
            // 播放状态指示器
            if isPlaying {
                Image(systemName: "stop.fill")
                    .foregroundColor(.red)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "music.note")
                    .foregroundColor(.primary)
                    .frame(width: 16, height: 16)
            }
            
            // 歌曲信息 - 水平单行显示
            HStack(spacing: 4) {
                Text(music.title)
                    .font(.subheadline) // 缩小字体
                    .foregroundColor(isPlaying ? .red : .primary)
                    .lineLimit(1)
                
                Text("—") // 分隔符
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(music.artist)
                    .font(.caption) // 缩小字体
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 删除按钮（始终显示）
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle()) // 无样式按钮
        }
        .padding(.vertical, 4) // 减少垂直内边距来降低行高
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
