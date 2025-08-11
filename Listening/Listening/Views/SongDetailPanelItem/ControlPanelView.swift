import SwiftUI

struct ControlPanelView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var audioPlayer: AudioPlayer  // 用于控制音量
    
    // 新增绑定：曲率和模糊属性
    @Binding var curvature: Double
    @Binding var blur: Double
    
    let lightModeSecondary = Color(red: 60/255, green: 60/255, blue: 67/255, opacity: 0.6)
    
    // 自定义垂直滑块组件
    private func verticalSlider(value: Binding<Double>, label: String) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .foregroundColor(.white)
                .font(.caption)
            
            VStack {
                // 最大值在顶部
                
                
                // 垂直滑块
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        // 轨道背景
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 20)
                        
                        // 填充轨道（从下到上）
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray)
                            .frame(
                                width: 20,
                                height: min(CGFloat(value.wrappedValue) * geometry.size.height, geometry.size.height)
                            )
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                // 计算滑块值 (0-1)
                                let position = max(0, min(gesture.location.y, geometry.size.height))
                                let newValue = Double(1 - (position / geometry.size.height))
                                value.wrappedValue = max(0, min(newValue, 1))
                            }
                    )
                    .frame(height: 80)
                }
                .frame(height: 80)
                .padding(.horizontal, 23)
                
                // 最小值在底部
                
            }
            
            Text("\(Int(value.wrappedValue * 100))%")
                .foregroundColor(.white)
                .font(.caption)
        }
    }
    
    var body: some View {
        VStack(spacing: 15) {
            // 取消按钮
            /*
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
                .padding(.top, 10)
                .padding(.leading, 10)
                
                Spacer()
            }*/
            
            // 新增：自定义音量控制滑块
            verticalSlider(
                value: $audioPlayer.customVolume,
                label: "强度"
            )
            
            // 曲率控制
            verticalSlider(value: $curvature, label: "曲率")
            
            // 模糊控制
            verticalSlider(value: $blur, label: "模糊")
        }
        .frame(width: 100, height: 500)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(lightModeSecondary))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
    }
}
