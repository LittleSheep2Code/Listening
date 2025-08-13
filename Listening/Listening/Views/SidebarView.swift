import SwiftUI

// 新增：歌单批量操作栏组件
struct PlaylistBatchOperationBar: View {
    let selectedCount: Int
    let onDelete: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack {
            // 左侧：取消按钮
            Button(action: onCancel) {
                Image(systemName: "xmark")
            }.padding(.horizontal)
            
            Spacer()
            
            // 中部：选择计数
            Text("已选 \(selectedCount) 项")
                .font(.subheadline).padding(.vertical, 12)
            
            Spacer()
            
            // 右侧：删除按钮（红色）
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }.padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.regularMaterial) // 使用半透明材料背景
        .cornerRadius(10)
        .shadow(radius: 5) // 添加轻微阴影
        .padding()
    }
}

private struct AboutButton: View {
    let isEditing: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            onSelect()
        }) {
            HStack {
                Image(systemName: "info.circle").frame(width: 24)
                Text("关于")
                    .font(.headline)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .listRowBackground(
            isSelected ?
            Color.gray.opacity(0.3) :
                Color(UIColor.systemGray6)
        )
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    }
}

private struct AllSongsButton: View {
    let isEditing: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            onSelect()
        }) {
            HStack {
                Image(systemName: "music.note.house").frame(width: 24)
                Text("全部歌曲")
                    .font(.headline)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .listRowBackground(
            isSelected ?
            Color.gray.opacity(0.3) :
                Color(UIColor.systemGray6)
        )
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    }
}

private struct PlaylistsSection: View {
    let playlists: [Playlist]
    let isEditing: Bool
    @Binding var selectedPlaylistIds: Set<UUID>
    @Binding var currentView: RightViewType?
    let onDelete: (IndexSet) -> Void
    let onMove: ((IndexSet, Int) -> Void)?
    let onCreatePlaylist: () -> Void
    
    var body: some View {
        Section(header:
                    HStack {
            Text("我的歌单")
                .font(.headline)
            Button(action: onCreatePlaylist) {
                Image(systemName: "plus")
            }
            .disabled(isEditing)
            
            Spacer()
            
        }
            .padding(.top, 8)
            .padding(.bottom, 4)
            .textCase(nil)
        ) {
            ForEach(playlists) { playlist in
                PlaylistListItemView(
                    playlist: playlist,
                    isSelected: Binding(
                        get: { selectedPlaylistIds.contains(playlist.id) },
                        set: { isSelected in
                            if isSelected {
                                selectedPlaylistIds.insert(playlist.id)
                            } else {
                                selectedPlaylistIds.remove(playlist.id)
                            }
                        }
                    ),
                    isEditing: .constant(isEditing),
                    onSelect: {
                        if !isEditing {
                            currentView = .playlist(id: playlist.id)
                        }
                    }
                )
                .listRowBackground(
                    (currentView?.isPlaylist(playlist.id) ?? false) ?
                    Color.gray.opacity(0.3) :
                        Color.clear
                )
            }
            .onDelete(perform: isEditing ? nil : onDelete)
            .onMove(perform: isEditing ? onMove : nil)
        }
        
        if isEditing {
            Color.clear
                .listRowBackground(
                    Color.clear
                )
        }
    }
}

struct SidebarView: View {
    @ObservedObject private var playlistManager = PlaylistManager.shared
    @Binding var currentView: RightViewType?
    let playlists: [Playlist]
    let onDelete: (IndexSet) -> Void
    let onCreatePlaylist: () -> Void
    
    @State private var isEditing = false
    @State private var selectedPlaylistIds = Set<UUID>()
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // 主列表内容
                List(selection: $currentView) {
                    AllSongsButton(
                        isEditing: isEditing,
                        isSelected: currentView?.isLibrary ?? false,
                        onSelect: {
                            currentView = .library
                            if isEditing {
                                isEditing = false
                                selectedPlaylistIds = []
                            }
                        }
                    )
                    
                    AboutButton(
                        isEditing: isEditing,
                        isSelected: currentView?.isAbout ?? false,
                        onSelect: {
                            currentView = .about
                            if isEditing {
                                isEditing = false
                                selectedPlaylistIds = []
                            }
                        }
                    )
                    
                    PlaylistsSection(
                        playlists: playlists,
                        isEditing: isEditing,
                        selectedPlaylistIds: $selectedPlaylistIds,
                        currentView: $currentView,
                        onDelete: onDelete,
                        onMove: movePlaylists,
                        onCreatePlaylist: onCreatePlaylist
                    )
                    .onAppear {
                        // Workaround to enable the plus button action here
                    }
                }
                .listStyle(.insetGrouped)
                .navigationBarTitleDisplayMode(.inline)
                
                // 编辑模式下的操作栏（使用新的组件）
                if isEditing {
                    PlaylistBatchOperationBar(
                        selectedCount: selectedPlaylistIds.count,
                        onDelete: batchDeletePlaylists,
                        onCancel: {
                            isEditing = false
                            selectedPlaylistIds = []
                        }
                    )
                    .transition(.move(edge: .bottom))
                }
            }
            .toolbar {
                // 左侧工具栏：选择/完成按钮和全选按钮
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    // 选择/完成按钮
                    Button(isEditing ? "完成" : "选择") {
                        isEditing.toggle()
                        if !isEditing {
                            selectedPlaylistIds = []
                        }
                    }
                    
                    // 全选按钮（只在编辑模式下显示）
                    if isEditing {
                        Button("全选") {
                            if selectedPlaylistIds.count == playlists.count {
                                selectedPlaylistIds = []
                            } else {
                                selectedPlaylistIds = Set(playlists.map { $0.id })
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 批量删除歌单
    private func batchDeletePlaylists() {
        for id in selectedPlaylistIds {
            if let playlist = playlistManager.getPlaylist(by: id) {
                playlistManager.deletePlaylist(playlist)
            }
        }
        selectedPlaylistIds = []
        isEditing = false
    }
    
    // 拖拽排序歌单
    private func movePlaylists(from source: IndexSet, to destination: Int) {
        playlistManager.movePlaylists(from: source, to: destination)
    }
}

// 扩展用于检查视图状态
extension RightViewType {
    var isAbout: Bool {
        if case .about = self {
            return true
        }
        return false
    }
    
    var isLibrary: Bool {
        if case .library = self {
            return true
        }
        return false
    }
    
    func isPlaylist(_ id: UUID) -> Bool {
        if case .playlist(let playlistId) = self, playlistId == id {
            return true
        }
        return false
    }
}
