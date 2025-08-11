import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject private var musicManager = GlobalMusicManager.shared
    @ObservedObject private var playlistManager = PlaylistManager.shared
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    @State private var showImporter = false
    @State private var importError: Error?
    @State private var showImportError = false
    @State private var isBatchEditing = false
    @State private var selectedItems: Set<UUID> = []
    @State private var showAddToPlaylistView = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    /*
                    Section {
                        
                        Button("同步文件索引") {
                            musicManager.syncWithFileSystem()
                        }
                    }
                     */
                    
                    Section(header: Text("所有音乐 (\(musicManager.musicFiles.count))")) {
                        if musicManager.musicFiles.isEmpty {
                            Text("暂无音乐文件")
                                .foregroundColor(.secondary)
                        }
                        
                        ForEach(Array(musicManager.musicFiles.enumerated()), id: \.element.id) { index, music in
                            MusicRow(
                                music: music,
                                currentPlayingID: $audioPlayer.currentPlayingID,
                                isPlaying: $audioPlayer.isPlaying,
                                playlistTag: "全部",
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
                                    musicManager.removeMusicFile(music)
                                },
                                deletionType: .global
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
                .listStyle(.insetGrouped)
                .navigationTitle("音乐库")
                .toolbar {
                    // 左上角：添加音乐按钮
                    ToolbarItem(placement: .topBarTrailing){
                        if isBatchEditing {
                            Button("全选") {
                                toggleSelectAll()
                            }
                            .fontWeight(.medium)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if !isBatchEditing {
                            Button {
                                showImporter = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 18))
                            }
                        }
                    }
                    // 右上角：选择/完成按钮
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isBatchEditing ? "完成" : "选择") {
                            isBatchEditing.toggle()
                            if !isBatchEditing {
                                selectedItems.removeAll()
                            }
                        }
                        .fontWeight(.medium)
                    }
                    
                }
                
                .fileImporter(
                    isPresented: $showImporter,
                    allowedContentTypes: [.audio],
                    allowsMultipleSelection: true
                ) { result in
                    handleImportResult(result)
                }
                .alert("导入失败", isPresented: $showImportError) {
                    Button("确定") {}
                } message: {
                    Text(importError?.localizedDescription ?? "未知错误")
                }
                
                // 使用原始的BatchOperationBar样式
                if isBatchEditing {
                    BatchOperationBar(
                        selectedCount: selectedItems.count,
                        onAddToPlaylist: addSelectedToPlaybackPlaylist,
                        onDelete: deleteSelectedItems,
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
        }
        // 显示批量添加到歌单的视图
        .sheet(isPresented: $showAddToPlaylistView) {
            if !selectedItems.isEmpty {
                AddMultipleToPlaylistView(musicIDs: Array(selectedItems))
            }
        }
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            musicManager.importMusicFiles(urls)
        } catch {
            importError = error
            showImportError = true
        }
    }
    
    private func deleteSelectedItems() {
        let itemsToDelete = musicManager.musicFiles.filter { selectedItems.contains($0.id) }
        for item in itemsToDelete {
            musicManager.removeMusicFile(item)
        }
        selectedItems.removeAll()
        isBatchEditing = false
    }
    
    private func addSelectedToPlaybackPlaylist() {
        let manager = PlaybackPlaylistManager.shared
        let itemsToAdd = musicManager.musicFiles.filter { selectedItems.contains($0.id) }
        
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
        if selectedItems.count == musicManager.musicFiles.count {
            selectedItems.removeAll()
        } else {
            selectedItems = Set(musicManager.musicFiles.map { $0.id })
        }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        guard isBatchEditing else { return }
        
        var items = musicManager.musicFiles
        items.move(fromOffsets: source, toOffset: destination)
        musicManager.musicFiles = items
    }
}

// 保留原始的BatchOperationBar结构体
struct BatchOperationBar: View {
    let selectedCount: Int
    let onAddToPlaylist: () -> Void
    let onDelete: () -> Void
    let onAddToPlaylistDetail: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
            }
            
            Spacer()
            
            Text("已选 \(selectedCount) 项")
                .font(.subheadline)
            
            Spacer()
            
            Menu {
                Button(action: onAddToPlaylistDetail) {
                    Label("添加到歌单", systemImage: "text.badge.plus")
                }
                Button(action: onAddToPlaylist) {
                    Label("添加到播放列表", systemImage: "plus.rectangle.on.folder")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
        }
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}
