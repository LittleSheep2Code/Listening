import SwiftUI

struct PlaylistDetailView: View {
    @ObservedObject private var playlistManager = PlaylistManager.shared
    @ObservedObject private var musicManager = GlobalMusicManager.shared
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    @State private var isBatchEditing = false
    @State private var selectedItems: Set<UUID> = []
    @State private var showAddToPlaylistView = false
    @State private var showManagementView = false
    
    let playlistId: UUID
    
    // 计算属性：获取当前歌单
    private var playlist: Playlist? {
        playlistManager.getPlaylist(by: playlistId)
    }
    
    // 计算属性：获取歌单中的音乐
    private var playlistMusics: [MusicFile] {
        guard let playlist = playlist else { return [] }
        return playlistManager.getMusics(for: playlist)
    }
    
    // 计算属性：获取歌单总时长
    private var playlistDuration: String {
        guard let playlist = playlist else { return "0min" }
        return GlobalMusicManager.shared.totalDuration(for: playlist.musicIDs)
    }
    
    var body: some View {
        NavigationStack {  // 明确使用 NavigationStack
            ZStack(alignment: .bottom) {
                List {
                    // 歌单头部信息
                    if let playlist = playlist {
                        ZStack(alignment: .top) {
                            // 背景层：模糊封面（解决List高度问题）
                            if let coverData = playlist.coverImageData,
                               let uiImage = UIImage(data: coverData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                /* ⚙️ 背景高度调整点 - 推荐200-300 */
                                    .frame(height: 200)
                                    .clipped()
                                    .blur(radius: 20)
                                    .opacity(0.8)
                                    .overlay(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            } else {
                                Color(UIColor.systemGray5)
                                /* ⚙️ 背景高度同步调整 */
                                    .frame(height: 200)
                                    .overlay(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                            
                            // 内容层（封面+元信息）
                            VStack(alignment: .leading, spacing: 0) {
                                Spacer().frame(height: 40) // ⚙️ 顶部间距调整点
                                
                                HStack(alignment: .top, spacing: 20) {
                                    // 封面（固定大小）
                                    if let coverData = playlist.coverImageData,
                                       let uiImage = UIImage(data: coverData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                        /* ⚙️ 封面大小调整点 */
                                            .frame(width: 120, height: 120)
                                            .cornerRadius(10)
                                            .shadow(radius: 5)
                                    } else {
                                        Image(systemName: "music.note.list")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 100, height: 100)
                                            .foregroundColor(.white)
                                            .padding(10)
                                            .background(Color.gray.opacity(0.7))
                                            .cornerRadius(10)
                                    }
                                    
                                    // 元信息（三列布局）
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(playlist.name)
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        /* ⚙️ 行数限制调整 */
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        // 歌曲数量
                                        HStack {
                                            Image(systemName: "music.note")
                                                .foregroundColor(.white.opacity(0.8))
                                            Text("\(playlist.musicIDs.count) 首歌曲")
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                        }
                                        
                                        // 创建日期
                                        HStack {
                                            Image(systemName: "calendar")
                                                .foregroundColor(.white.opacity(0.8))
                                            Text("创建于 \(playlist.createdAt.formatted(date: .long, time: .omitted))")
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                        }
                                        
                                        // 时长（示例）
                                        HStack {
                                            Image(systemName: "clock")
                                                .foregroundColor(.white.opacity(0.8))
                                            Text(playlistDuration) // 计算时长
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                        }
                                        
                                        Spacer()
                                    }
                                    /* ⚙️ 元信息顶部间距调整 */
                                    .padding(.top, 0)
                                    
                                    Spacer()
                                }
                                /* ⚙️ 左右边距调整点 */
                                .padding(.horizontal, 20)
                            }
                        }
                        /* ⚙️ 整个头部高度调整 - 必须与背景高度匹配 */
                        .frame(height: 200)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        
                    }
                    
                    // 歌曲列表
                    Section(header: Text("歌曲列表")) {
                        if playlistMusics.isEmpty {
                            Text("歌单为空")
                                .foregroundColor(.secondary)
                        }
                        
                        ForEach(Array(playlistMusics.enumerated()), id: \.element.id) { index, music in
                            MusicRow(
                                music: music,
                                currentPlayingID: $audioPlayer.currentPlayingID,
                                isPlaying: $audioPlayer.isPlaying,
                                playlistTag: playlist?.name ?? "歌单",
                                index: index,
                                isBatchEditing: $isBatchEditing,
                                isSelected: Binding(
                                    get: { selectedItems.contains(music.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedItems.insert(music.id)
                                        } else {
                                            selectedItems.remove(music.id)
                                        }
                                    }
                                ),
                                onDelete: {
                                    if let playlist = playlist {
                                        playlistManager.removeMusicFromPlaylist(musicID: music.id, playlist: playlist)
                                    }
                                },
                                deletionType: .playlist
                            )
                        }
                        .onMove(perform: isBatchEditing ? moveItems : nil) // 只在选择模式下启用拖拽
                    }
                    
                    if isBatchEditing {
                        Color.clear
                            .listRowBackground(
                                Color.clear
                            )
                    }
                    
                }
                .listStyle(.insetGrouped) // 使用分组样式更好展示内容
                
                // 底部操作栏 (仅在选择模式下显示)
                if isBatchEditing && !playlistMusics.isEmpty {
                    BatchOperationBar(
                        selectedCount: selectedItems.count,
                        onAddToPlaylist: addSelectedToPlaybackPlaylist,
                        onDelete: removeSelectedFromPlaylist,
                        onAddToPlaylistDetail: {
                            showAddToPlaylistView = true
                        },
                        onCancel: {
                            isBatchEditing = false
                            selectedItems.removeAll()
                        }
                    )
                    .transition(.move(edge: .bottom))
                }
            }
            .navigationTitle(playlist?.name ?? "歌单详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("管理") {
                        showManagementView = true
                    }
                }
                
                // 左侧工具栏：编辑模式下显示全选按钮
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isBatchEditing {
                        Button("全选") {
                            toggleSelectAll()
                        }
                    }
                }
                
                // 右侧工具栏：选择/完成切换按钮
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isBatchEditing.toggle()
                        if !isBatchEditing {
                            selectedItems.removeAll()
                        }
                    }) {
                        Text(isBatchEditing ? "完成" : "选择")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showManagementView) {
            if let playlist = playlist {
                PlaylistManagementView(playlist: playlist)
            }
        }
        .sheet(isPresented: $showAddToPlaylistView) {
            if !selectedItems.isEmpty {
                AddMultipleToPlaylistView(musicIDs: Array(selectedItems))
            }
        }
        .onAppear {
            // 确保开始时不处于编辑状态
            isBatchEditing = false
            selectedItems.removeAll()
        }
        
    }
    
    // 以下所有功能方法保持原样
    private func removeSelectedFromPlaylist() {
        guard let playlist = playlist else { return }
        playlistManager.removeMultipleMusicFromPlaylist(musicIDs: Array(selectedItems), playlist: playlist)
        selectedItems.removeAll()
        isBatchEditing = false
    }
    
    private func addSelectedToPlaybackPlaylist() {
        let manager = PlaybackPlaylistManager.shared
        let itemsToAdd = playlistMusics.filter { selectedItems.contains($0.id) }
        
        // 批量处理每首选中的歌曲
        for music in itemsToAdd {
            // 确保歌曲不在播放列表中（避免重复）
            if let existingIndex = manager.musicFiles.firstIndex(where: { $0.id == music.id }) {
                manager.musicFiles.remove(at: existingIndex)
            }
            
            // 确定插入位置
            if let currentPlayingID = audioPlayer.currentPlayingID,
               let currentIndex = manager.musicFiles.firstIndex(where: { $0.id == currentPlayingID }) {
                // 插入到当前播放歌曲的下一首位置
                let insertIndex = currentIndex + 1
                manager.musicFiles.insert(music, at: insertIndex)
            } else {
                // 添加到列表最后
                manager.musicFiles.append(music)
            }
        }
        
        selectedItems.removeAll()
        isBatchEditing = false
        
        // 如果没有正在播放的歌曲，直接播放第一首
        if audioPlayer.currentPlayingID == nil {
            audioPlayer.currentPlayingID = manager.musicFiles.first?.id
        }
    }
    
    private func toggleSelectAll() {
        if selectedItems.count == playlistMusics.count {
            selectedItems.removeAll()
        } else {
            selectedItems = Set(playlistMusics.map { $0.id })
        }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        guard isBatchEditing, let playlist = playlist else { return }
        
        var items = playlistMusics
        items.move(fromOffsets: source, toOffset: destination)
        
        // 更新歌单中的音乐顺序
        let musicIDs = items.map { $0.id }
        playlistManager.updateMusicOrder(in: playlist.id, with: musicIDs)
    }
}
