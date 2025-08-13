import SwiftUI

struct CurvedLyricRow: View {
    let index: Int
    let lyric: LyricLine
    let isCurrent: Bool
    let isClosestToCenter: Bool
    let curvature: Double
    let blur: Double // 新增模糊参数
    let panelCenterY: CGFloat
    let onTapped: () -> Void
    
    let darkModeSecondary = Color(red: 235/255, green: 235/255, blue: 245/255, opacity: 0.6)
    
    @State private var preCurveDistanceFromPanelCenter: CGFloat = 0
    
    var body: some View {
        // 获取自身位置
        GeometryReader { geometry in
            HStack {
                Text(lyric.text)
                    .foregroundColor(textColor)
                    .opacity(computedOpacity) // 应用计算出的透明度
                    .blur(radius: computedBlur)
                /*
                Text("\(Int(abs(preCurveDistanceFromPanelCenter)))px")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(.leading, 8)*/
            }
            .font(fontStyle)
            .scaleEffect(isCurrent ? 1.1 : 1.0)
            .animation(.spring(), value: isCurrent)
            .offset(x: arcOffset.x, y: arcOffset.y) // 改为圆弧偏移计算
            .rotationEffect(.radians(rotationAngle)) // 新增：旋转修饰符
            .onTapGesture(perform: onTapped)
            .frame(maxWidth: .infinity, alignment: .center)
            .onChange(of: geometry.frame(in: .global), initial: true) { _,_ in
                updatePreCurveDistance(geometry: geometry)
            }
            // 发送距离值给父视图
            .preference(
                key: LineCenterDistancePreference.self, 
                value: [LineDistanceData(index: index, distance: preCurveDistanceFromPanelCenter)]
            )
        }
        .frame(height: 30)
    }
    
    // 新增：圆弧偏移计算
    private var arcOffset: (x: CGFloat, y: CGFloat) {
        guard curvatureEffectFactor >= 0 && curvature > 0 else {
            return (0, 0) // 无曲率效果时不偏移
        }
        
        // 计算动态半径 (曲率0:10000, 曲率1:600)
        let baseRadius: CGFloat = 1000
        let minRadius: CGFloat = 30
        let radius = baseRadius - (baseRadius - minRadius) * CGFloat(curvature * 0.72)
        
        // 计算基本角度 (r * sin(alpha) = 60)
        let alpha = asin(60 / radius)
        
        // 计算当前行的偏移角度
        let theta = (preCurveDistanceFromPanelCenter / 60) * alpha
        

        
        // 计算圆弧坐标偏移量
        let xOffset = radius * (cos(theta) - 1)
        let yOffset = -radius * sin(theta) + preCurveDistanceFromPanelCenter
        
        return (xOffset, yOffset)
    }
    
    // 字体样式逻辑（保持不变）
    private var fontStyle: Font {
        if isCurrent {
            return .system(size: 24, weight: .bold)
        } else {
            return .system(size: 20)
        }
    }
    
    // 文字颜色逻辑（保持不变）
    private var textColor: Color {
        if isCurrent {
            return .white
        } else if isClosestToCenter {
            return .white
        } else {
            return darkModeSecondary
        }
    }
    
    // 更新弯曲处理前的距离（保持不变）
    private func updatePreCurveDistance(geometry: GeometryProxy) {
        let viewCenterY = geometry.frame(in: .global).midY
        preCurveDistanceFromPanelCenter = viewCenterY - panelCenterY
    }
    
    // 计算曲率效果因子（保持不变）
    private var curvatureEffectFactor: CGFloat {
        let absDistance = abs(preCurveDistanceFromPanelCenter)
        let maxEffectDistance: CGFloat = 600
        return absDistance > maxEffectDistance ? -1 : absDistance / maxEffectDistance
    }
    
    private var rotationAngle: Double {
        guard curvatureEffectFactor >= 0 && curvature > 0 else {
            return 0 // 无曲率效果时返回0
        }
        
        // 计算动态半径（恢复原始规格）
        let baseRadius: CGFloat = 10000
        let minRadius: CGFloat = 600
        let radius = baseRadius - (baseRadius - minRadius) * CGFloat(curvature * 0.72)
        
        // 计算基本角度
        let alpha = asin(60 / radius)
        
        // 计算偏移角度
        let theta = (preCurveDistanceFromPanelCenter / 60) * alpha
        let beta = 7 * theta
        
        // 返回旋转角度（保持符号以确定方向）
        return Double(beta)
    }
    
    private var computedOpacity: Double {
        // 计算透明度
        let Opacity = 1 * Double(abs(preCurveDistanceFromPanelCenter)) / 320
        let Judgment = Double(abs(preCurveDistanceFromPanelCenter)) / 320
        
        // 应用透明度规则
        if Judgment > 1 {
            return 0
        } else if Opacity >= 0.2 {
            // 0.5-1之间线性映射到0-1 (0.5→0, 1→1)
            return 1 - (Opacity - 0.2) * 1.25
        } else {
            // 小于0.5保持不变
            return 1
        }
    }
    
    private var computedBlur: Double {
        // 计算相对距离（距离与320的比例）
        let normalizedDistance = Double(abs(preCurveDistanceFromPanelCenter)) / 320
        
        // 应用模糊规则
        if normalizedDistance > 1 {
            // 超过阈值320时保持最大模糊
            return blur * 10
        } else if normalizedDistance >= 0 {
            // 在0.1到1之间从0到blur线性增加模糊
            return (normalizedDistance - 0) * (blur * 1.11) * 10
        } else {
            // 接近中心时不模糊
            return 0
        }
    }

}


