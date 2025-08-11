import SwiftUI

struct LyricsPanelView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject var globalMusicManager: GlobalMusicManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    @Binding var isCompact: Bool
    @Binding var currentTime: TimeInterval
    @Binding var curvature: Double
    @Binding var blur: Double
    
    private var totalDuration: TimeInterval {
        audioPlayer.totalDuration
    }
    
    @State private var showLyricImporter = false
    @State private var importFailed = false
    @State private var panelCenterY: CGFloat = 0 // 存储面板中心位置
    
    private var lyricContent: String? {
        guard let currentID = audioPlayer.currentPlayingID else { return nil }
        return globalMusicManager.getLyrics(forMusic: currentID)
    }
    
    var body: some View {
        // 使用 GeometryReader 测量面板中心位置
        GeometryReader { geometry in
            VStack {
                if let currentID = audioPlayer.currentPlayingID, 
                    let content = lyricContent, 
                    !content.isEmpty {
                    LyricsDisplayView(
                        lyricContent: content,
                        musicID: currentID,
                        currentTime: $currentTime,
                        totalDuration: .constant(totalDuration),
                        curvature: $curvature,
                        blur: $blur,
                        isCompact: $isCompact,
                        panelCenterY: panelCenterY // 传递面板中心位置
                    )
                    .environmentObject(audioPlayer)
                } else {
                    VStack(spacing: 15) {
                        Text("未找到歌词")
                            .font(horizontalSizeClass == .compact ? .headline : .title3)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Button(action: importLyrics) {
                            HStack {
                                Image(systemName: "plus")
                                Text("导入歌词文件")
                            }
                            .padding(10)
                            .cornerRadius(10)
                            .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.clear)
            .cornerRadius(12)
            .onChange(of: geometry.frame(in: .global), initial: true) { _, _  in
                // 当面板位置变化时更新中心位置
                self.panelCenterY = geometry.frame(in: .global).midY
            }
        }
        .fileImporter(
            isPresented: $showLyricImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleLyricImport(result: result)
        }
        .alert("导入失败", isPresented: $importFailed) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("请选择有效的 .lrc 歌词文件")
        }
    }
    
    private func importLyrics() {
        showLyricImporter = true
    }
    
    private func handleLyricImport(result: Result<[URL], Error>) {
        guard let currentID = audioPlayer.currentPlayingID else { return }
        
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            
            if url.pathExtension.lowercased() != "lrc" {
                importFailed = true
                return
            }
            
            globalMusicManager.importLyricFile(url: url, forMusic: currentID)
        } catch {
            print("导入失败: \(error)")
            importFailed = true
        }
    }
    
    private func timeString(_ time: TimeInterval) -> String {
        let minute = Int(time) / 60
        let second = Int(time) % 60
        return String(format: "%02d:%02d", minute, second)
    }
}
