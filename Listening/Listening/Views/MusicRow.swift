import SwiftUI
import UIKit

struct MusicRow: View {
    let music: MusicFile
    @EnvironmentObject var audioPlayer: AudioPlayer  
    
    @Binding var currentPlayingID: UUID?
    @Binding var isPlaying: Bool
    
    var playlistTag: String? = nil
    var index: Int? // 用于显示在列表中的位置索引
    
    @Binding var isBatchEditing: Bool
    @Binding var isSelected: Bool
    
    // 删除操作回调
    var onDelete: (() -> Void)? = nil
    var deletionType: DeletionType = .global
    
    
    
    enum DeletionType {
        case global // 从音乐库删除（所有位置）
        case playlist // 从当前歌单删除
    }
    
    // 状态控制
    @State private var showAddToPlaylistView = false
    @State private var showEditMetadataView = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    // 计算属性：当前歌曲是否正在播放
    private var isCurrentPlaying: Bool {
        audioPlayer.isPlaying && audioPlayer.currentPlayingID == music.id
    }
    
    var body: some View {
        HStack(spacing: 0) {
            
            if isBatchEditing {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .padding(.trailing, 20)
                    .onTapGesture {
                        isSelected.toggle()
                    }
                
            }
            
            // 左侧内容区（点击播放/暂停）
            leftContentSection
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isBatchEditing {
                        if !isCurrentPlaying {
                            togglePlayback()
                        }
                    }
                    if isBatchEditing {
                        isSelected.toggle()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 右侧菜单区域（三点按钮）
            if !isBatchEditing {
                menuSection
            }
            
            if isBatchEditing {
                Image(systemName: "line.3.horizontal")
                    .padding(.horizontal, 5)
                    .foregroundColor(.gray)
                    .font(.system(size: 20))
                
            }
        }
        .padding(.vertical, 2)
        .sheet(isPresented: $showAddToPlaylistView) {
            AddToPlaylistView(musicID: music.id)
        }
        .sheet(isPresented: $showEditMetadataView) {
            EditMetadataView(music: music)
        }
        .sheet(isPresented: $showShareSheet) {
            // 使用自定义的ShareSheet视图
            ShareSheet(activityItems: $shareItems)
        }
    }
    
    // 左侧内容区域（整个左侧部分覆盖点击手势）
    private var leftContentSection: some View {
        HStack(spacing: 12) {
            // 左侧标识：播放状态或索引
            Group {
                if isCurrentPlaying {
                    if !isBatchEditing {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(.blue)
                            .font(.subheadline)
                            .frame(width: 24, alignment: .center)
                    }
                } else if let index = index {
                    if !isBatchEditing {
                        Text("\(index + 1)")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .frame(width: 24, alignment: .center)
                    }
                } else {
                    Text("")
                        .frame(width: 24)
                }
            }
            
            // 歌曲信息（垂直布局）
            VDisplay(title: music.title, artist: music.artist)
            
            Spacer()
        }
    }
    
    // 分离视图解决表达式复杂问题
    private struct VDisplay: View {
        let title: String
        let artist: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                Text(artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Text(" ")
        }
    }
    
    // 右侧菜单区域（竖排三点按钮）
    private var menuSection: some View {
        Menu {
            // 菜单内容
            Button(action: shareMusic) {
                Label("分享歌曲", systemImage: "square.and.arrow.up")
            }
            
            Button(action: { 
                showEditMetadataView = true
            }) {
                Label("编辑元信息", systemImage: "pencil")
            }
            
            Button(action: { 
                if !isCurrentPlaying {
                    addToPlayNext()
                }
            }) {
                Label("下一首播放", systemImage: "text.insert")
            }
            .disabled(isCurrentPlaying) // 已包含此逻辑
            
            Button(action: { 
                showAddToPlaylistView = true 
            }) {
                Label("添加到歌单", systemImage: "plus")
            }
            
            // 删除选项
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label(
                        deletionType == .global ? "删除歌曲(所有位置)" : "从歌单移除", 
                        systemImage: deletionType == .global ? "trash" : "minus.circle"
                    )
                }
            }
        } label: {
            // 扩大点击区域
            Image(systemName: "ellipsis")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .rotationEffect(.degrees(90)) // 旋转90度变成垂直方向
                .foregroundColor(.gray)
                .padding(10)
        }
        .frame(width: 30) // 减少宽度使其靠近边缘
    }
    
    // MARK: - 播放/停止切换
    private func togglePlayback() {
        if isCurrentPlaying {
            audioPlayer.stop()
            currentPlayingID = nil
            isPlaying = false
        } else {
            playMusic()
        }
    }
    
    // MARK: - 添加到下一首播放
    private func addToPlayNext() {
        let manager = PlaybackPlaylistManager.shared
        
        // 从歌曲列表中找到当前歌曲的索引
        let existingIndex = manager.musicFiles.firstIndex { $0.id == music.id }
        
        // 如果歌曲已在播放列表中，先移除原有位置
        if let indexToRemove = existingIndex {
            manager.musicFiles.remove(at: indexToRemove)
        }
        
        // 获取当前播放歌曲的索引
        if let currentPlayingID = audioPlayer.currentPlayingID,
           let currentIndex = manager.musicFiles.firstIndex(where: { $0.id == currentPlayingID }) {
            // 将歌曲插入到当前播放的下一首位置
            let insertIndex = currentIndex + 1
            manager.musicFiles.insert(music, at: insertIndex)
        } else {
            // 如果没有正在播放的歌曲，直接添加到列表最后
            manager.musicFiles.append(music)
        }
    }
    
    private func playMusic() {
        // 只有当有歌单标签时才加载播放列表
        if let tag = playlistTag {
            PlaybackPlaylistManager.shared.loadPlaylist(fromTag: tag) {
                // 显式调用播放方法，确保触发播放
                self.audioPlayer.play(music: self.music)
            }
        } else {
            // 直接调用播放方法
            audioPlayer.play(music: music)
        }
    }
    
    private func playAfterListUpdated(for music: MusicFile) {
        // 在播放列表更新后播放当前歌曲
        currentPlayingID = music.id
        isPlaying = true
        
        // 通知播放列表管理器开始播放
        PlaybackPlaylistManager.shared.playTrack(music)
    }
    
    private func shareMusic() {
        // 使用歌曲元数据匹配文件URL
        if let fileURL = GlobalMusicManager.shared.fileURL(
            forTitle: music.title, 
            artist: music.artist
        ) {
            shareItems = [fileURL]
            showShareSheet = true
        }
    }
}


struct ShareSheet: UIViewControllerRepresentable {
    @Binding var activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems, 
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // 不需要更新逻辑
    }
}
