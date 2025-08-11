import SwiftUI

enum RightViewType : Hashable {
    case library
    case playlist(id: UUID)
}



struct EmptyPlaylistView: View {
    @State private var showCreator = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("暂无歌单")
                .font(.title2)
            
            Text("创建歌单来整理你的音乐收藏")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("创建歌单") {
                showCreator = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 20)
        }
        .frame(maxHeight: .infinity)
        .sheet(isPresented: $showCreator) {
            NewPlaylistView()
        }
    }
}

struct NewPlaylistView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var playlistName = ""
    @State private var showingDuplicateError = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("歌单名称")) {
                    TextField("输入歌单名称", text: $playlistName)
                        .autocapitalization(.words)
                }
                
                Section {
                    Button("创建歌单") {
                        createPlaylist()
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
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("创建") {
                        createPlaylist()
                    }
                    .disabled(playlistName.isEmpty)
                }
            }
        }
    }
    
    private func createPlaylist() {
        let playlistManager = PlaylistManager.shared
        let nameExists = playlistManager.playlists.contains { playlist in
            playlist.name.lowercased() == playlistName.lowercased()
        }
        
        if nameExists {
            showingDuplicateError = true
            return
        }
        
        playlistManager.createPlaylist(name: playlistName)
        presentationMode.wrappedValue.dismiss()
    }
}
