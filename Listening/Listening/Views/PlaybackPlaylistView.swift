// File: PlaybackPlaylistView.swift
import SwiftUI

struct PlaybackPlaylistView: View {
    @ObservedObject var manager: PlaybackPlaylistManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    var body: some View {
        Group {
            if manager.musicFiles.isEmpty {
                VStack {
                    Text("当前播放列表为空")
                        .font(.title2)
                        .padding(.bottom, 5)
                    
                    Text("在音乐库或我的歌单中选择歌曲开始播放列表")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    // 播放列表标题
                    // 歌曲列表 - 使用新的PlaylistRow
                    ForEach(manager.musicFiles) { music in
                        // 在 PlaylistDetailView 中使用 PlaylistRow
                        PlaylistRow(
                            music: music,
                            isPlaying: audioPlayer.currentPlayingID == music.id && audioPlayer.isPlaying,
                            onTap: {
                                if audioPlayer.currentPlayingID != music.id {
                                    audioPlayer.play(music: music)
                                }
                            },
                            onDelete: {
                                // 从播放列表中删除歌曲
                                manager.removeFromPlaylist(music)
                                
                                // 如果删除的是当前播放歌曲，需要特殊处理
                                if audioPlayer.currentPlayingID == music.id {
                                    audioPlayer.stop()
                                }
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(manager.playlistTag)
        .onChange(of: audioPlayer.currentPlayingID) { _,newID in
            // 使用显式状态比较确保正确更新
            if manager.currentPlayingID != newID {
                manager.currentPlayingID = newID
            }
        }
        .onChange(of: audioPlayer.isPlaying) { _,newPlaying in
            // 当播放状态改变时确保UI刷新
            if !newPlaying && manager.currentPlayingID != nil {
                manager.stopPlayback()
            }
        }
    }
}
