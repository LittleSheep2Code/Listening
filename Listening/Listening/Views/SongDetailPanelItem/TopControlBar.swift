import SwiftUI

struct TopControlBar: View {
    let dismissAction: () -> Void
    let shareAction: () -> Void
    
    var body: some View {
        HStack {
            // 关闭按钮
            Button(action: dismissAction) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .padding(14)
                // .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            .padding(.leading, 20)
            .padding(.top, 10)
            
            Spacer()
            
            // 分享按钮
            Button(action: shareAction) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .padding(14)
                //   .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            .padding(.trailing, 20)
            .padding(.top, 10)
        }
        .padding(.top, 0)
    }
}
