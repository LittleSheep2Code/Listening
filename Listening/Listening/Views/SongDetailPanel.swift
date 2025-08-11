import SwiftUI
import AVFoundation

struct SongDetailPanel: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var audioPlayer: AudioPlayer
    @Binding var showPanel: Bool
    @State private var showControlPanel = false
    let coverImage: UIImage
    @Binding var currentTime: TimeInterval
    @Binding var totalTime: TimeInterval
    @Binding var progress: Float
    @Binding var isSeeking: Bool
    
    // 新增状态：曲率和模糊
    @AppStorage("lyricCurvature") private var curvature: Double = 0.5
    @AppStorage("lyricBlur") private var blur: Double = 0.5
    
    // 分享相关状态
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    // 播放列表弹窗状态
    @State private var showAddToPlaylistSheet = false
    @State private var showClearConfirmAfterPopup = false
    @State var clearAlertType: ClearAlertType = .emptyPlaylist
    
    @State var isCompact = false
    
    enum ClearAlertType {
        case emptyPlaylist
        case confirmClear
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                let backgroundView = DetailBackgroundView(coverImage: coverImage)
                
                // 主内容区
                VStack(spacing: 0) {
                    let leftPanel = LeftPanelView(
                        coverImage: coverImage,
                        coverWidth: geometry.size.width * 0.4,
                        progress: $progress,
                        currentTime: $currentTime,
                        totalTime: $totalTime,
                        isSeeking: $isSeeking,
                        showAddToPlaylistSheet: $showAddToPlaylistSheet,
                        showClearConfirmAfterPopup: $showClearConfirmAfterPopup,
                        clearAlertType: $clearAlertType,
                        showControlPanel: $showControlPanel // 传递绑定状态
                    )
                        .environmentObject(audioPlayer)
                        .frame(alignment: .top)
                    
                    let lyricsPanel = LyricsPanelView(
                        isCompact: $isCompact,
                        currentTime: $currentTime,
                        curvature: $curvature,  // 传递曲率绑定
                        blur: $blur             // 传递模糊绑定
                    )
                        .environmentObject(GlobalMusicManager.shared)
                        .environmentObject(audioPlayer)
                    
                    if isCompact {
                        TabView {
                            ZStack {
                                backgroundView
                                leftPanel
                            }
                                .tag("info")
                                .toolbarBackgroundVisibility(Visibility.hidden, for: .tabBar)
                                .tabItem { Label("详情", systemImage: "play.fill") }
                            
                            ZStack {
                                backgroundView
                                lyricsPanel
                            }
                                .tag("lyrics")
                                .toolbarBackground(Visibility.hidden, for: .tabBar)
                                .toolbarBackgroundVisibility(Visibility.hidden, for: .tabBar)
                                .tabItem { Label("歌词", systemImage: "music.note.list") }
                            
                        }.background(Color(white: 0, opacity: 0))
                    } else {
                        ZStack {
                            backgroundView
                            HStack(spacing: 30) {
                                leftPanel.frame(width: geometry.size.width * 0.5, height: geometry.size.height)
                                lyricsPanel.frame(width: geometry.size.width * 0.5, height: geometry.size.height)
                            }
                        }
                    }
                }
                
                // 顶部控制栏
                TopControlBar(dismissAction: { dismiss() }, shareAction: shareCurrentMusic)
                    .frame(width: geometry.size.width)
                    .position(x: geometry.size.width * 0.5, y: 40)
                
                
                // 在最上层添加控制面板
                if showControlPanel {
                    ControlPanelView(
                        isPresented: $showControlPanel,
                        curvature: $curvature,  // 传递曲率绑定
                        blur: $blur             // 传递模糊绑定
                    )
                    .environmentObject(audioPlayer)  // 传递音频播放器
                    .offset(x: 20, y: 0)
                    .position(x: geometry.size.width - 60,
                              y: geometry.size.height * 0.5)
                    
                }
            }
            .onChange(of: geometry.size.width, initial: true) { oldWidth, newWidth in
                // runs once on appear (initial: true), then whenever width changes
                isCompact = newWidth < 840
            }
        }
        .background(Color.black)
        
        // 添加分享弹出层
        .sheet(isPresented: $showShareSheet) {
            if !shareItems.isEmpty {
                ShareSheet2(activityItems: $shareItems)
            }
        }
        .sheet(isPresented: $showAddToPlaylistSheet) {
            AddMultipleToPlaylistView(musicIDs: PlaybackPlaylistManager.shared.musicFiles.map { $0.id })
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
                        PlaybackPlaylistManager.shared.clearPlaylist()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    // 分享当前歌曲
    private func shareCurrentMusic() {
        guard let currentID = audioPlayer.currentPlayingID,
              let music = GlobalMusicManager.shared.getMusic(by: currentID),
              let fileURL = GlobalMusicManager.shared.fileURL(for: music.fileName) else {
            return
        }
        shareItems = [fileURL]  // 直接赋值单个文件URL的数组
        showShareSheet = true
    }
}
