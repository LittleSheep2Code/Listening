import SwiftUI
import AVFoundation


struct LeftPanelView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var audioPlayer: AudioPlayer
    let coverImage: UIImage
    let coverWidth: CGFloat
    @Binding var progress: Float
    @Binding var currentTime: TimeInterval
    @Binding var totalTime: TimeInterval
    @Binding var isSeeking: Bool
    @Binding var showAddToPlaylistSheet: Bool
    @Binding var showClearConfirmAfterPopup: Bool
    @Binding var clearAlertType: SongDetailPanel.ClearAlertType
    @Binding var showControlPanel: Bool
    
    // 新增：播放列表弹窗状态
    @State private var showPlaylistPopover = false
    
    var maxCoverSize: CGFloat = 320
    
    var body: some View {
        VStack(alignment: .center, spacing: 40) {
            // 大封面
            Image(uiImage: coverImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: min(coverWidth, maxCoverSize), height: min(coverWidth, maxCoverSize))
                .cornerRadius(12)
                .shadow(radius: 10)
            
            HStack {
                // 歌曲信息
                if let currentMusic = GlobalMusicManager.shared.getMusic(by: audioPlayer.currentPlayingID ?? UUID()) {
                    HStack(spacing: 4) {
                        Text(currentMusic.title)
                            .font(.system(size: 20)) // 缩小字体
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundColor(.white)
                        
                        Text("-") // 分隔符
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        Text(currentMusic.artist)
                            .font(.footnote) // 缩小字体
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                } else {
                    Text("无播放内容")
                        .font(.footnote)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        if !showControlPanel{
                            showControlPanel = true
                        }
                        else{
                            showControlPanel = false
                        }
                        
                    }
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(5)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 55)
            
            // 进度条和时间
            VStack(spacing: 20){
                HStack {
                    Text(timeString(from: currentTime))
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(timeString(from: totalTime))
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 55)
                
                VStack(spacing: 25){
                    // 自定义进度条
                    ZStack(alignment: .leading) {
                        GeometryReader { geometry in
                            let width = geometry.size.width  // 实时获取容器宽度
                            
                            // 背景轨道
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 2.5)
                            
                            
                            // 进度条
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.cyan)
                                .frame(width: CGFloat(progress) * width, height: 2.5)
                            // 移除动画 - 拖拽时需即时响应
                                .animation(nil, value: progress)
                            
                            // 拖拽手柄
                            
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue.opacity(0.0001), lineWidth: 80)
                                        .scaleEffect(audioPlayer.isSeeking ? 1.2 : 1)
                                )
                                .offset(x: CGFloat(progress) * width - 8, y: 0 - 5 + 1.25)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { gesture in
                                            isSeeking = true
                                            // 直接使用最新宽度计算位置
                                            let dragLocation = gesture.location.x
                                            let normalizedValue = max(0, min(dragLocation / width, 1))
                                            progress = Float(normalizedValue)
                                                
                                            // 立即请求重绘
                                            DispatchQueue.main.async {
                                                currentTime = totalTime * TimeInterval(normalizedValue)
                                            }
                                        }
                                        .onEnded { _ in
                                            audioPlayer.seek(to: Double(progress))
                                            isSeeking = false
                                        }
                                )
                                // 拖拽时禁用动画
                                .transaction { transaction in
                                    if isSeeking { transaction.animation = nil }
                                }
                        }
                        .frame(height: 16)  // 确保点击区域足够大
                    }
                    
                }
                .padding(.horizontal, 60)
            }
            
            // 控制按钮行
            HStack(spacing: 52) {
                // 播放模式
                Button(action: {
                    audioPlayer.cyclePlaybackMode()
                }) {
                    Image(systemName: audioPlayer.playbackMode.systemImage)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width:20,height:20)
                }
                
                // 上一首
                Button(action: {
                    audioPlayer.playPreviousTrack()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                // 播放/暂停
                Button(action: {
                    audioPlayer.togglePlayPause()
                }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill" )
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                
                // 下一首
                Button(action: {
                    audioPlayer.playNextTrack()
                }) {
                    Image(systemName: "forward.fill" )
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                // 播放列表 - 添加popover到按钮
                Button(action: {
                    showPlaylistPopover = true
                }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                .popover(isPresented: $showPlaylistPopover, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
                    // 播放列表弹窗内容
                    PlaylistPopoverView(
                        showPlaylistPopover: $showPlaylistPopover,
                        showAddToPlaylistSheet: $showAddToPlaylistSheet,
                        showClearConfirmAfterPopup: $showClearConfirmAfterPopup,
                        clearAlertType: $clearAlertType
                    )
                    .environmentObject(audioPlayer)
                    .presentationCompactAdaptation(.popover)
                }
            }
            .padding(.vertical, 0)
        }
    }
    
    private func timeString(from time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
