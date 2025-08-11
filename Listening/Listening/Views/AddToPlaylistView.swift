import SwiftUI

struct AddToPlaylistView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var playlistManager = PlaylistManager.shared
    let musicID: UUID
    
    @State private var showAddNewPlaylistView = false
    
    var body: some View {
        NavigationView {
            Group {
                if playlistManager.playlists.isEmpty {
                    VStack {
                        Text("暂无歌单")
                            .foregroundColor(.secondary)
                            .padding(.top, 20)
                        
                        Button(action: {
                            showAddNewPlaylistView = true
                        }) {
                            Text("创建新歌单")
                        }
                    }
                } else {
                    List(playlistManager.playlists) { playlist in
                        Button(action: {
                            addToPlaylist(playlist)
                        }) {
                            HStack {
                                // 显示歌单封面
                                if let coverData = playlist.coverImageData,
                                   let uiImage = UIImage(data: coverData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .cornerRadius(5)
                                } else {
                                    // 默认图标
                                    Image(systemName: "music.note.list")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.gray)
                                        .padding(5)
                                        .background(Color(UIColor.systemGray5))
                                        .cornerRadius(5)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(playlist.name)
                                        .font(.headline)
                                    Text("\(playlist.musicIDs.count) 首")
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 1)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("添加到歌单")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("新建歌单") {
                        showAddNewPlaylistView = true
                    }
                }
            }
            .sheet(isPresented: $showAddNewPlaylistView, onDismiss: {}) {
                NewPlaylistViewForAdding(
                    onComplete: { name in
                        // 仅传递歌单名称
                        handleNewPlaylistCreation(name: name)
                    },
                    onCancel: {
                        showAddNewPlaylistView = false
                    }
                )
            }
        }
    }
    
    private func addToPlaylist(_ playlist: Playlist) {
        playlistManager.addMusicToPlaylist(musicID, playlist: playlist)
        presentationMode.wrappedValue.dismiss()
    }
    
    // 统一处理新建歌单逻辑
    private func handleNewPlaylistCreation(name: String) {
        // 确保歌单存在（内部自动去重）
        playlistManager.createPlaylist(name: name)
        
        // 查找实际存在的歌单对象
        if let playlist = playlistManager.playlists.first(where: { $0.name == name }) {
            playlistManager.addMusicToPlaylist(musicID, playlist: playlist)
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}

struct NewPlaylistViewForAdding: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var playlistName = ""
    @State private var showingDuplicateError = false
    var onComplete: (String) -> Void  // 改为接收字符串
    var onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("歌单名称")) {
                    TextField("输入歌单名称", text: $playlistName)
                        .autocapitalization(.words)
                }
                
                Section {
                    Button("创建歌单") {
                        validateAndCreate()
                    }
                    .disabled(playlistName.isEmpty)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("新建歌单")
            .alert(isPresented: $showingDuplicateError) {
                Alert(
                    title: Text("歌单名称重复"),
                    message: Text("已存在同名歌单，请使用不同的名称"),
                    dismissButton: .default(Text("确定"))
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("创建") {
                        validateAndCreate()
                    }
                    .disabled(playlistName.isEmpty)
                }
            }
        }
    }
    
    private func validateAndCreate() {
        // 仅进行重复检查，不实际创建歌单
        if PlaylistManager.shared.playlistNameExists(playlistName) {
            showingDuplicateError = true
            return
        }
        
        // 传递歌单名称给父视图
        onComplete(playlistName)
        presentationMode.wrappedValue.dismiss()
    }
}
