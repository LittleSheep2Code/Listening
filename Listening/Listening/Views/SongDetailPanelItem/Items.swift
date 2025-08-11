import SwiftUI
import AVFoundation


struct CoverImageView: View {
    let coverImage: UIImage
    let width: CGFloat
    
    var body: some View {
        Image(uiImage: coverImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: width)
            .cornerRadius(12)
            .shadow(radius: 10)
    }
}

struct ProgressView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @Binding var progress: Float
    @Binding var currentTime: TimeInterval
    @Binding var totalTime: TimeInterval
    @Binding var isSeeking: Bool
    let totalWidth: CGFloat
    
    var body: some View {
        VStack {
            HStack {
                Text(timeString(from: currentTime))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(timeString(from: totalTime))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundColor(.white)
            }
            
            // 自定义进度条
            ZStack(alignment: .leading) {
                
                Rectangle()
                    .fill(Color.white.opacity(0.00001))
                    .frame(height: 4)
                
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)
                
                
                
                Rectangle()
                    .fill(Color.cyan)
                    .frame(width: CGFloat(progress) * totalWidth, height: 4)
                    .animation(.linear(duration: 0.01), value: progress)
                
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 16, height: 16)
                    .offset(x: CGFloat(progress) * totalWidth - 8, y: 0)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged({ gesture in
                                isSeeking = true
                                let newValue = min(max(0, gesture.location.x / totalWidth), 1)
                                progress = Float(newValue)
                                currentTime = totalTime * TimeInterval(newValue)
                            })
                            .onEnded({ _ in
                                audioPlayer.seek(to: Double(min(progress, 1.0)))
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                    isSeeking = false
                                }
                            })
                    )
            }
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

struct ShareSheet2: UIViewControllerRepresentable {
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

struct PlaylistPopoverView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @Binding var showPlaylistPopover: Bool
    @Binding var showAddToPlaylistSheet: Bool
    @Binding var showClearConfirmAfterPopup: Bool
    @Binding var clearAlertType: SongDetailPanel.ClearAlertType
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    audioPlayer.cyclePlaybackMode()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: audioPlayer.playbackMode.systemImage)
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 24, height: 24)
                            .foregroundColor(.secondary)
                        
                        switch audioPlayer.playbackMode {
                        case .loopAll:
                            Text("列表循环")
                                .foregroundColor(.secondary)
                        case .loopOne:
                            Text("单曲循环")
                                .foregroundColor(.secondary)
                        case .random:
                            Text("随机播放")
                                .foregroundColor(.secondary)
                        }
                        
                        Text("(\(PlaybackPlaylistManager.shared.musicFiles.count))")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.gray.opacity(0))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                
                Spacer()
                
                Button(action: {
                    showPlaylistPopover = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showAddToPlaylistSheet = true
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 16, weight: .bold))
                        Text("收藏")
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0))
                    .cornerRadius(8)
                    .foregroundColor(.secondary)
                }
                
                Button(action: {
                    showPlaylistPopover = false
                    if PlaybackPlaylistManager.shared.musicFiles.isEmpty {
                        clearAlertType = .emptyPlaylist
                    } else {
                        clearAlertType = .confirmClear
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showClearConfirmAfterPopup = true
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                    .background(Color.red.opacity(0))
                    .cornerRadius(8)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            
            // 播放列表内容
            PlaybackPlaylistView(manager: PlaybackPlaylistManager.shared)
                .environmentObject(audioPlayer)
                .frame(height: min(400, UIScreen.main.bounds.height * 0.55) - 40)
        }
        .frame(width: max(UIScreen.main.bounds.width * 0.33, 480))
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(UIColor.separator), lineWidth: 0.5)
        )
    }
}
