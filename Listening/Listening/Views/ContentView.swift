import SwiftUI

struct ContentView: View {
    @ObservedObject private var playlistManager = PlaylistManager.shared
    @State private var showPlaylistCreator = false
    @StateObject private var audioPlayer = AudioPlayer.shared
    @StateObject private var playbackManager = PlaybackPlaylistManager.shared
    
    @State private var selection: RightViewType?
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                SidebarView(
                    currentView: $selection,
                    playlists: playlistManager.playlists,
                    onDelete: deletePlaylists,
                    onCreatePlaylist: { showPlaylistCreator = true }
                )
            } detail: {
                switch selection {
                case .library:
                    LibraryView()
                        .environmentObject(audioPlayer)
                case .playlist(let id):
                    PlaylistDetailView(playlistId: id)
                        .environmentObject(audioPlayer)
                case .none:
                    Text("Unselected")
                }
            }
            
            BottomPlayerView()
                .environmentObject(audioPlayer)
        }
        .sheet(isPresented: $showPlaylistCreator) {
            NewPlaylistView()
        }
        .onReceive(playlistManager.$playlistUpdateTrigger) { _ in
            // Kept from original code
        }
    }
    
    private func deletePlaylists(at offsets: IndexSet) {
        for index in offsets {
            playlistManager.deletePlaylist(playlistManager.playlists[index])
        }
    }
}
