import SwiftUI

struct ContentView: View {
    @ObservedObject private var playlistManager = PlaylistManager.shared
    @State private var showPlaylistCreator = false
    @StateObject private var audioPlayer = AudioPlayer.shared
    @StateObject private var playbackManager = PlaybackPlaylistManager.shared
    
    @State private var selection: RightViewType?
    @State private var isCompact: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                NavigationSplitView {
                    SidebarView(
                        currentView: $selection,
                        playlists: playlistManager.playlists,
                        onDelete: deletePlaylists,
                        onCreatePlaylist: { showPlaylistCreator = true }
                    )
                    .navigationSplitViewColumnWidth(geo.size.width * 0.4)
                } detail: {
                    switch selection {
                    case .library:
                        LibraryView()
                            .environmentObject(audioPlayer)
                            .padding(.horizontal, isCompact ? 0 : 4)
                    case .playlist(let id):
                        PlaylistDetailView(playlistId: id)
                            .environmentObject(audioPlayer)
                            .padding(.horizontal, isCompact ? 0 : 4)
                    case .about, .none:
                        AboutView()
                            .toolbarVisibility(isCompact ? Visibility.automatic : Visibility.hidden, for: .navigationBar)
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
            .onChange(of: geo.size.width, initial: true) { oldWidth, newWidth in
                isCompact = newWidth < 840
                if !isCompact && selection == .none {
                    selection = .library
                }
            }
        }
    }
    
    private func deletePlaylists(at offsets: IndexSet) {
        for index in offsets {
            playlistManager.deletePlaylist(playlistManager.playlists[index])
        }
    }
}
