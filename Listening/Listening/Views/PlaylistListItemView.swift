import SwiftUI

struct PlaylistListItemView: View {
    let playlist: Playlist
    @Binding var isSelected: Bool
    @Binding var isEditing: Bool
    var onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            if isEditing {
                isSelected.toggle()
            } else {
                onSelect()
            }
        }) {
            ZStack(alignment: .leading) {
                // 背景层：模糊封面图片
                if let coverData = playlist.coverImageData,
                   let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 60) // 行高固定为60
                        .clipped()
                        .blur(radius: 15) // 模糊效果增强
                        .opacity(0.7)
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    // 没有封面时使用渐变色背景
                    /*
                    LinearGradient(
                        gradient: Gradient(colors: [Color(white: 0.01), .gray]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                     */
                    Color.secondary
                        .frame(height: 60)
                }
                
                // 内容层：文本和选中标志
                HStack {
                    // 编辑模式下显示选择按钮
                    if isEditing {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .blue : .white)
                            .padding(.leading, 8)
                            .transition(.scale)
                    }
                    
                    // 封面图标
                    if let coverData = playlist.coverImageData,
                       let uiImage = UIImage(data: coverData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .cornerRadius(4)
                            .padding(.leading, isEditing ? 0 : 8)
                    } else {
                        Image(systemName: "music.note.list")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.leading, isEditing ? 0 : 8)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(playlist.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("\(playlist.musicIDs.count) 首歌曲")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 8)
                    
                    Spacer()
                    
                    if isEditing {
                        Image(systemName: "line.3.horizontal")
                            .padding(.horizontal, 10)
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                        
                    }
                    
                }
                .padding(.vertical, 0)
                
                // 选中效果：半透明灰色层
                if isSelected && isEditing {
                    Color.gray.opacity(0.3)
                        .frame(height: 60)
                }
            }
            .frame(height: 60)
        }
        .buttonStyle(PlainButtonStyle()) // 使用无样式按钮
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
    }
}
