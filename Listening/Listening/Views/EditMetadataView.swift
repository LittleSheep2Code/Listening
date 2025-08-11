import SwiftUI
import PhotosUI
import UniformTypeIdentifiers // 添加导入用于文件选择器

struct EditMetadataView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var manager = GlobalMusicManager.shared // 添加观察对象
    
    let music: MusicFile
    @State private var title: String
    @State private var artist: String
    @State private var coverImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var showDocumentPicker = false // 用于歌词文件选择器
    
    init(music: MusicFile) {
        self.music = music
        _title = State(initialValue: music.title)
        _artist = State(initialValue: music.artist)
        _coverImage = State(initialValue: GlobalMusicManager.shared.getCoverImage(for: music))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("歌曲信息")) {
                    TextField("标题", text: $title)
                    TextField("艺术家", text: $artist)
                    
                    VStack(alignment: .leading) {
                        Text("封面图片").font(.subheadline).foregroundColor(.secondary)
                        coverImageSection
                    }
                }
                
                // 新增: 歌词文件管理区域
                Section(header: Text("歌词文件")) {
                    // 显示当前歌词文件状态
                    if let lyricFileName = manager.getMusic(by: music.id)?.lyricFileName {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("当前关联歌词:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text(lyricFileName)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                Spacer()
                                
                                // 取消关联按钮
                                Button(action: removeLyric) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    } else {
                        Text("未关联歌词文件")
                            .foregroundColor(.secondary)
                    }
                    
                    // 导入歌词文件按钮
                    /*
                    Button(action: { showDocumentPicker = true }) {
                        Label("导入歌词文件", systemImage: "doc.text")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }*/
                }
            }
            .navigationTitle("编辑元信息")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveChanges()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onChange(of: photoItem) { newItem in
                loadPhoto(item: newItem)
            }
            .sheet(isPresented: $showDocumentPicker) {
                // 歌词文件选择器
                DocumentPicker(types: [.plainText, UTType(filenameExtension: "lrc")!]) { urls in
                    if let url = urls.first {
                        importLyricFile(url: url)
                    }
                }
            }
        }
    }
    
    private var coverImageSection: some View {
        HStack {
            // 封面显示区域
            Group {
                if let coverImage = coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.gray)
                }
            }
            .cornerRadius(8)
            
            Spacer()
            
            // 操作按钮区域
            VStack(spacing: 16) {
                // 选择图片按钮
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("选择封面", systemImage: "photo.on.rectangle.angled")
                        .frame(minWidth: 150)
                        .padding(10)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                }
                
                // 删除按钮（仅当有图片显示时显示）
                if coverImage != nil {
                    Button(role: .destructive) {
                        coverImage = nil
                    } label: {
                        Label("删除封面", systemImage: "trash")
                            .frame(minWidth: 150)
                            .padding(10)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
                
                // 还原原始专辑封面按钮
                Button {
                    if let originalCover = getOriginalCoverImage(for: music) {
                        coverImage = originalCover
                    } else {
                        coverImage = nil
                    }
                } label: {
                    Label("还原原始专辑封面", systemImage: "arrow.uturn.backward")
                        .frame(minWidth: 150)
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // 从文件元数据中提取原始封面
    private func getOriginalCoverImage(for music: MusicFile) -> UIImage? {
        guard let fileURL = manager.fileURL(for: music.fileName) else { return nil }
        
        let asset = AVURLAsset(url: fileURL)
        for metadataItem in asset.metadata {
            guard metadataItem.commonKey == .commonKeyArtwork,
                  let data = metadataItem.dataValue,
                  let image = UIImage(data: data) else { continue }
            
            return image
        }
        
        return nil
    }
    
    // 新增: 加载照片
    private func loadPhoto(item: PhotosPickerItem?) {
        Task {
            if let data = try? await item?.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                coverImage = image
            }
        }
    }
    
    // 新增: 移除歌词关联
    private func removeLyric() {
        manager.removeLyricFile(forMusic: music.id)
    }
    
    // 新增: 导入歌词文件
    private func importLyricFile(url: URL) {
        manager.importLyricFile(url: url, forMusic: music.id)
    }
    
    private func saveChanges() {
        manager.updateMusicMetadata(
            for: music.id,
            newTitle: title,
            newArtist: artist,
            newCoverImage: coverImage
        )
    }
}

// 新增: DocumentPicker 用于选择歌词文件
struct DocumentPicker: UIViewControllerRepresentable {
    var types: [UTType]
    var onPick: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
        }
    }
}
