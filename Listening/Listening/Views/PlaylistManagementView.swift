import SwiftUI
import UIKit

struct PlaylistManagementView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var playlistManager = PlaylistManager.shared
    
    var playlist: Playlist
    @State private var playlistName: String
    @State private var coverImageData: Data?
    @State private var showImagePicker = false
    @State private var manualCoverMode: Bool
    @State private var errorMessage: String?
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    init(playlist: Playlist) {
        self.playlist = playlist
        _playlistName = State(initialValue: playlist.name)
        _coverImageData = State(initialValue: playlist.coverImageData)
        _manualCoverMode = State(initialValue: playlist.isManualCover)
    }
    
    var body: some View {
        NavigationView {
            Form {
                
                Section(header: Text("基本信息")) {
                    TextField("歌单名称", text: $playlistName)
                        .onChange(of: playlistName) { _ in
                            // 清除之前的错误消息
                            errorMessage = nil
                        }
                    
                    if let message = errorMessage {
                        Text(message)
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("封面设置")) {
                    // 封面预览
                    HStack {
                        Spacer()
                        if let coverData = coverImageData, let uiImage = UIImage(data: coverData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                                .cornerRadius(10)
                        } else {
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                                .foregroundColor(.gray)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    
                    // 更改封面按钮
                    Button(action: {
                        showImagePicker = true
                    }) {
                        Label("选择新封面", systemImage: "photo.on.rectangle")
                    }
                    
                    // 手动模式开关
                    Toggle("手动更新封面", isOn: $manualCoverMode)
                        .onChange(of: manualCoverMode) { _,newValue in
                            // 开启手动模式时标记封面为手动设置
                            if newValue && coverImageData != nil {
                                playlistManager.markCoverAsManual(for: playlist.id)
                            }
                        }
                }
                
                // 删除歌单选项
                Section {
                    Button(action: {
                        playlistManager.deletePlaylist(playlist)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Spacer()
                            Text("删除歌单")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("管理歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        
                        saveChanges()
                       // presentationMode.wrappedValue.dismiss()
                        
            
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(imageData: $coverImageData)
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("操作失败"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
    }
    
    private func saveChanges() {
        // 验证并更新名称
        if playlistName != playlist.name {
            if let error = playlistManager.updatePlaylistName(playlistId: playlist.id, newName: playlistName) {
                // 名称更新失败，显示弹窗
                alertMessage = error
                showAlert = true
                return // 停止保存过程
            }
        }
        
        // 更新封面图片（如果有变化）
        if coverImageData != playlist.coverImageData {
            playlistManager.updatePlaylistCoverImage(
                playlistId: playlist.id,
                coverImageData: coverImageData,
                markManual: true
            )
        }
        
        // 更新封面模式
        if manualCoverMode != playlist.isManualCover {
            playlistManager.toggleManualCover(for: playlist)
        }
        
        // 如果所有更新成功，关闭视图
        presentationMode.wrappedValue.dismiss()
    }
}

// 图片选择器工具视图
struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var imageData: Data?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController, 
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.imageData = uiImage.jpegData(compressionQuality: 0.8)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
