import SwiftUI
import AVFoundation
import UIKit

struct BottomPlayerView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject var audioPlayer: AudioPlayer
    @ObservedObject var playlistManager = PlaybackPlaylistManager.shared
    
    // 统一管理所有图标的颜色
    private let iconColor = Color.cyan
    private let vstackBackgroundColor = Color(UIColor.systemBackground)
    
    // 创建纯灰色占位图
    private let placeholderCover: UIImage = {
        // 创建50x50大小的纯灰色图片
        let size = CGSize(width: 50, height: 50)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor.systemGray5.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        }
    }()
    
    @State private var showPlaylist = false
    @State private var geometry: CGSize? = nil
    @State private var coverImage: UIImage? = nil
    @State private var defaultCover = UIImage(named: "Logo")!
    @State private var showClearConfirm = false
    @State private var showClearConfirmAfterPopup = false
    @State private var clearAlertType: ClearAlertType = .emptyPlaylist
    @State private var showAddToPlaylistSheet = false
    
    // 新状态控制歌曲详情面板
    @State private var showSongDetailPanel = false
    
    // 枚举区分不同提示类型
    internal enum ClearAlertType {
        case emptyPlaylist
        case confirmClear
    }
    
    // 播放列表弹出视图尺寸
    private var playlistSize: CGSize {
        let screenSize = UIScreen.main.bounds.size
        return CGSize(width: max(screenSize.width * 0.33, 480),
                      height: min(400, screenSize.height * 0.55))
    }
    
    @State var isCompact = false
    
    @StateObject private var audioPlayerViewModel = AudioPlayerViewModel(audioPlayer: AudioPlayer.shared)

    var body: some View {
        VStack(spacing: 7) {
            Divider()
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.size, initial: true) { newSize, _ in
                        isCompact = newSize.width < 500
                    }
                    .frame(width: 0, height: 0)
                HStack(alignment: .center, spacing: isCompact ? 12 : 25) {
                    if isCompact {
                        // 封面（紧凑模式下也显示）
                        BottomCoverImageView(
                            coverImage: coverImage,
                            defaultCover: defaultCover
                        ) {
                            guard !audioPlayer.isSeeking else { return }
                            showSongDetailPanel = true
                        }
                        .onReceive(audioPlayer.$currentPlayingID) { id in
                            if let id = id, let music = GlobalMusicManager.shared.getMusic(by: id) {
                                loadCoverImage(for: music)
                            }
                        }
                    } else {
                        // 封面（正常模式）
                        BottomCoverImageView(
                            coverImage: coverImage,
                            defaultCover: defaultCover
                        ) {
                            guard !audioPlayer.isSeeking else { return }
                            showSongDetailPanel = true
                        }
                        .onReceive(audioPlayer.$currentPlayingID) { id in
                            if let id = id, let music = GlobalMusicManager.shared.getMusic(by: id) {
                                loadCoverImage(for: music)
                            }
                        }
                    }
                    // 播放控制
                    PlaybackControlsView(
                        isPlaying: audioPlayer.isPlaying,
                        onPrevious: { audioPlayer.playPreviousTrack() },
                        onTogglePlayPause: { audioPlayer.togglePlayPause() },
                        onNext: { audioPlayer.playNextTrack() },
                        iconColor: iconColor,
                        compact: isCompact
                    )
                    if isCompact {
                        // 进度条（紧凑模式下展示，隐藏标题等信息）
                        ProgressInfoView(
                            currentMusic: GlobalMusicManager.shared.getMusic(by: audioPlayer.currentPlayingID ?? UUID()),
                            currentTime: audioPlayerViewModel.currentTime,
                            totalTime: audioPlayerViewModel.totalTime,
                            progress: audioPlayerViewModel.progress,
                            isSeeking: audioPlayer.isSeeking,
                            onSeek: { newProgress in
                                audioPlayer.isSeeking = true
                                audioPlayerViewModel.progress = newProgress
                                DispatchQueue.main.async {
                                    audioPlayerViewModel.currentTime = audioPlayerViewModel.totalTime * TimeInterval(newProgress)
                                }
                            },
                            onSeekEnded: {
                                audioPlayer.seek(to: Double(audioPlayerViewModel.progress))
                                audioPlayer.isSeeking = false
                            },
                            geometry: $geometry,
                            horizontalSizeClass: .compact // 强制紧凑，隐藏标题/艺术家
                        )
                    } else {
                        Spacer()
                        // 进度和歌曲信息
                        ProgressInfoView(
                            currentMusic: GlobalMusicManager.shared.getMusic(by: audioPlayer.currentPlayingID ?? UUID()),
                            currentTime: audioPlayerViewModel.currentTime,
                            totalTime: audioPlayerViewModel.totalTime,
                            progress: audioPlayerViewModel.progress,
                            isSeeking: audioPlayer.isSeeking,
                            onSeek: { newProgress in
                                audioPlayer.isSeeking = true
                                audioPlayerViewModel.progress = newProgress
                                DispatchQueue.main.async {
                                    audioPlayerViewModel.currentTime = audioPlayerViewModel.totalTime * TimeInterval(newProgress)
                                }
                            },
                            onSeekEnded: {
                                audioPlayer.seek(to: Double(audioPlayerViewModel.progress))
                                audioPlayer.isSeeking = false
                            },
                            geometry: $geometry,
                            horizontalSizeClass: horizontalSizeClass
                        )
                        // 播放模式
                        if horizontalSizeClass != .compact {
                            PlaybackModeButton(
                                mode: audioPlayer.playbackMode,
                                iconColor: iconColor
                            ) {
                                audioPlayer.cyclePlaybackMode()
                            }
                        }
                    }
                    // 播放列表按钮
                    PlaylistButtonView(
                        playlistManager: playlistManager,
                        showPlaylist: $showPlaylist,
                        playlistSize: playlistSize,
                        iconColor: iconColor,
                        playbackMode: audioPlayer.playbackMode,
                        onCycleMode: { audioPlayer.cyclePlaybackMode() },
                        onAddToPlaylist: {
                            showPlaylist = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showAddToPlaylistSheet = true
                            }
                        },
                        onClearPlaylist: {
                            if playlistManager.musicFiles.isEmpty {
                                clearAlertType = .emptyPlaylist
                            } else {
                                clearAlertType = .confirmClear
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showClearConfirmAfterPopup = true
                            }
                        }
                    )
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 70)
        }
        .background(vstackBackgroundColor)
        .fullScreenCover(isPresented: $showSongDetailPanel) {
            SongDetailPanel(
                showPanel: $showSongDetailPanel,
                coverImage: coverImage ?? defaultCover,
                currentTime: $audioPlayerViewModel.currentTime,
                totalTime: $audioPlayerViewModel.totalTime,
                progress: $audioPlayerViewModel.progress,
                isSeeking: $audioPlayer.isSeeking
            )
            .environmentObject(audioPlayer)
        }
        .sheet(isPresented: $showAddToPlaylistSheet) {
            AddMultipleToPlaylistView(musicIDs: playlistManager.musicFiles.map { $0.id })
        }
        .alert(isPresented: $showClearConfirmAfterPopup) {
            switch clearAlertType {
            case .emptyPlaylist:
                return Alert(
                    title: Text("播放列表已空"),
                    message: Text("无需清空"),
                    dismissButton: .default(Text("确定"))
                )
            case .confirmClear:
                return Alert(
                    title: Text("确定清空播放列表吗？"),
                    message: Text("这将移除所有正在播放的歌曲"),
                    primaryButton: .destructive(Text("清空")) {
                        playlistManager.clearPlaylist()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onAppear { audioPlayerViewModel.startUpdatingProgress() }
        .onDisappear { audioPlayerViewModel.stopUpdatingProgress() }  
        .onReceive(audioPlayer.$currentPlayingID) { _ in
            if let player = audioPlayer.player {
                audioPlayerViewModel.currentTime = 0
                audioPlayerViewModel.totalTime = player.duration
                audioPlayerViewModel.progress = 0
            }
        }
    }
    
    private func loadCoverImage(for music: MusicFile) {
        // 直接使用管理器获取封面（会自动处理自定义封面）
        if let coverImage = GlobalMusicManager.shared.getCoverImage(for: music) {
            self.coverImage = coverImage
        } else {
            coverImage = nil
        }
    }
    
    private func timeString(from time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // 确认清空播放列表操作
    private func confirmClearPlaylist() {
        print("🟠 进入 confirmClearPlaylist 函数")
        
        // 检查播放列表是否为空
        print("🟠 播放列表歌曲数量: \(playlistManager.musicFiles.count)")
        guard !playlistManager.musicFiles.isEmpty else {
            print("🔴 播放列表为空，不执行清空操作")
            showAlert(title: "播放列表已空", message: "无需清空")
            return
        }
        
        print("🟠 当前UI线程: \(Thread.isMainThread ? "主线程" : "后台线程")")
        
        // 创建确认提示框
        print("🟠 创建 UIAlertController")
        let alert = UIAlertController(
            title: "确定清空播放列表吗？",
            message: "这将移除所有正在播放的歌曲",
            preferredStyle: .alert
        )
        
        // 添加取消按钮
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
            
        })
        
        // 添加清空按钮
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { _ in
            
            self.playlistManager.clearPlaylist()
            // 清除后关闭播放列表弹出视图
            self.showPlaylist = false
        })
        
        // 检查当前视图控制器的状态
        DispatchQueue.main.async {
            
            guard let rootVC = UIApplication.shared.keyWindow?.rootViewController else {
                return
            }
            
            // 尝试显示提示框
            rootVC.present(alert, animated: true) {
                
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                
            }
        }
    }
    
    // 显示简单提示框
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
}



// MARK: - Subviews

private struct BottomCoverImageView: View {
    let coverImage: UIImage?
    let defaultCover: UIImage
    let onTap: () -> Void
    
    var body: some View {
        Image(uiImage: coverImage ?? defaultCover)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 50, height: 50)
            .cornerRadius(8)
            .padding(.trailing, 8)
            .onTapGesture { onTap() }
    }
}

private struct PlaybackControlsView: View {
    let isPlaying: Bool
    let onPrevious: () -> Void
    let onTogglePlayPause: () -> Void
    let onNext: () -> Void
    let iconColor: Color
    let compact: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            if !compact {
                Button(action: onPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }
                .frame(width: 30, height: 30)
            }
            Button(action: onTogglePlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
                    .frame(width: 42, height: 42)
            }
            if !compact {
                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }
                .frame(width: 30, height: 30)
            }
        }
    }
}

private struct ProgressInfoView: View {
    let currentMusic: MusicFile?
    let currentTime: TimeInterval
    let totalTime: TimeInterval
    let progress: Float
    let isSeeking: Bool
    let onSeek: (Float) -> Void
    let onSeekEnded: () -> Void
    @Binding var geometry: CGSize?
    let horizontalSizeClass: UserInterfaceSizeClass?
    
    private func timeString(from time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                if horizontalSizeClass != .compact {
                    if let music = currentMusic {
                        HStack(spacing: 4) {
                            Text(music.title)
                                .font(.footnote)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text("-")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Text(music.artist)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    } else {
                        Text("无播放内容")
                            .font(.footnote)
                    }
                }
                Spacer()
                Text(timeString(from: currentTime))
                    .font(.caption2)
                    .monospacedDigit()
                Text("/")
                    .font(.caption2)
                Text(timeString(from: totalTime))
                    .font(.caption2)
                    .monospacedDigit()
            }
            .frame(height: 15)
            ZStack(alignment: .leading) {
                GeometryReader { geo in
                    let width = geo.size.width
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 2.5)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.cyan)
                        .frame(width: CGFloat(progress) * width, height: 2.5)
                        .animation(nil, value: progress)
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.blue.opacity(0.0001), lineWidth: 80)
                                .scaleEffect(isSeeking ? 1.2 : 1)
                        )
                        .offset(x: CGFloat(progress) * width - 8, y: 0 - 5 + 1.25)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    let dragLocation = gesture.location.x
                                    let normalizedValue = max(0, min(dragLocation / width, 1))
                                    onSeek(Float(normalizedValue))
                                }
                                .onEnded { _ in
                                    onSeekEnded()
                                }
                        )
                        .transaction { transaction in
                            if isSeeking { transaction.animation = nil }
                        }
                }
                .frame(height: 16)
            }
            .frame(height: 20)
            .padding(.vertical, 6)
        }
        .frame(height: 48)
        .padding(.leading, 12)
        .padding(.trailing, horizontalSizeClass == .compact ? 0 : 24)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onChange(of: geo.size, initial: true) { newSize, _ in
                        geometry = newSize
                    }
            }
        )
    }
}

private struct PlaybackModeButton: View {
    let mode: PlaybackMode
    let iconColor: Color
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            Image(systemName: mode.systemImage)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 1, height: 55)
        }
    }
}

private struct PlaylistButtonView: View {
    @ObservedObject var playlistManager: PlaybackPlaylistManager
    @Binding var showPlaylist: Bool
    let playlistSize: CGSize
    let iconColor: Color
    let playbackMode: PlaybackMode
    let onCycleMode: () -> Void
    let onAddToPlaylist: () -> Void
    let onClearPlaylist: () -> Void
    
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @State private var showAddToPlaylistSheet = false
    @State private var showClearConfirmAfterPopup = false
    @State private var clearAlertType: BottomPlayerView.ClearAlertType = .emptyPlaylist
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(dampingFraction: 0.7)) {
                showPlaylist.toggle()
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 22))
                    .foregroundColor(iconColor)
            }
            .padding(20)
            .contentShape(Rectangle())
        }
        .popover(isPresented: $showPlaylist, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Button(action: onCycleMode) {
                        HStack(spacing: 6) {
                            Image(systemName: playbackMode.systemImage)
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 24, height: 24)
                                .foregroundColor(.secondary)
                            switch playbackMode {
                            case .loopAll:
                                Text("列表循环").foregroundColor(.secondary)
                            case .loopOne:
                                Text("单曲循环").foregroundColor(.secondary)
                            case .random:
                                Text("随机播放").foregroundColor(.secondary)
                            }
                            Text("(\(playlistManager.musicFiles.count))")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .background(Color.gray.opacity(0))
                        .cornerRadius(12)
                    }
                    .padding(.leading, 16)
                    .buttonStyle(.plain)
                    Spacer()
                    Button(action: onAddToPlaylist) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 16, weight: .bold))
                            Text("收藏")
                                .font(.system(size: 14))
                        }
                        .padding(.trailing, 8)
                        .background(Color.blue.opacity(0))
                        .cornerRadius(8)
                        .foregroundColor(.secondary)
                    }
                    Button(action: onClearPlaylist) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .padding(.trailing, 24)
                        .background(Color.red.opacity(0))
                        .cornerRadius(8)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 16)
                .background(Color(UIColor.secondarySystemBackground))
                PlaybackPlaylistView(manager: playlistManager)
                    .environmentObject(audioPlayer)
                    .frame(width: playlistSize.width, height: playlistSize.height - 40)
            }
            .frame(width: playlistSize.width)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(UIColor.separator), lineWidth: 0.5)
            )
            .presentationCompactAdaptation(.popover)
        }
    }
}
