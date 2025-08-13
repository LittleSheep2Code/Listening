import SwiftUI

struct DetailBackgroundView: View {
    let coverImage: UIImage
    @State private var displayImage: UIImage
    @State private var animationTarget: UIImage?
    @State private var animationOpacity: Double = 0.0
    @State private var debounceTimerID: UUID?
    @State private var pendingTargetImage: UIImage?
    @State private var animationInProgress: Bool = false
    
    // 一致性检查计时器
    @State private var consistencyCheckTimerID: UUID?
    
    // 视图尺寸
    @State private var viewSize: CGSize = .zero
    
    init(coverImage: UIImage) {
        self.coverImage = coverImage
        self._displayImage = State(initialValue: coverImage)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 底层：当前显示的图像（使用实际屏幕尺寸）
                backgroundImageLayer(uiImage: displayImage)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(1.0)
                
                // 中间层：目标图像（动画过程中显示）
                if let target = animationTarget {
                    backgroundImageLayer(uiImage: target)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .opacity(animationOpacity)
                }
                
                // 顶层：固定覆盖层（始终可见）
                fixedOverlayLayer()
            }
            .onAppear {
                // 获取视图的实际尺寸
                viewSize = geometry.size
            }
            .onChange(of: geometry.size) { _,newSize in
                // 视图尺寸变化时更新
                viewSize = newSize
            }
        }
        .ignoresSafeArea()
        .onChange(of: coverImage) { _,newCoverImage in
            handleCoverChange(newCoverImage: newCoverImage)
        }
        .onDisappear {
            cancelDebounceTimer()
            cancelConsistencyCheckTimer()
        }
    }
    
    // MARK: - 背景图像层
    private func backgroundImageLayer(uiImage: UIImage) -> some View {
        Color.clear.overlay(
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        )
        .clipped()
    }
    
    // MARK: - 固定覆盖层
    private func fixedOverlayLayer() -> some View {
        ZStack{
            RoundedRectangle(cornerRadius: 1)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.black)
                .opacity(0.3)
            if UITraitCollection.current.userInterfaceStyle == .light {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.black)
                    .opacity(0.3)
            }
            
        }
        
    }
    
    // MARK: - 处理封面变化
    private func handleCoverChange(newCoverImage: UIImage) {
        pendingTargetImage = newCoverImage
        cancelConsistencyCheckTimer()
        
        if !animationInProgress {
            startAnimatedTransition(immediately: false)
        }
    }
    
    // MARK: - 启动动画过渡
    private func startAnimatedTransition(immediately: Bool) {
        cancelDebounceTimer()
        cancelConsistencyCheckTimer()
        
        guard let target = pendingTargetImage else { return }
        animationTarget = target
        
        if immediately {
            startAnimationCycle()
            return
        }
        
        let timerID = UUID()
        debounceTimerID = timerID
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard self.debounceTimerID == timerID else { return }
            self.startAnimationCycle()
        }
    }
    
    // MARK: - 启动动画循环
    private func startAnimationCycle() {
        guard let target = animationTarget else {
            animationInProgress = false
            return
        }
        
        animationOpacity = 0.0
        animationInProgress = true
        
        withAnimation(.easeInOut(duration: 1.0)) {
            animationOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.displayImage = target
            self.animationOpacity = 0.0
            self.animationTarget = nil
            
            // 保存待处理目标后清除
            let nextPending = self.pendingTargetImage
            self.pendingTargetImage = nil
            self.animationInProgress = false
            
            if let next = nextPending {
                // 有等待的更新则立即处理
                self.pendingTargetImage = next
                self.startAnimatedTransition(immediately: true)
            } else {
                // 无等待更新则启动3秒检查
                self.scheduleConsistencyCheck()
            }
        }
    }
    
    // MARK: - 计划一致性检查
    private func scheduleConsistencyCheck() {
        let timerID = UUID()
        consistencyCheckTimerID = timerID
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // 确保检查条件满足
            guard self.consistencyCheckTimerID == timerID,
                  !self.animationInProgress,
                  self.pendingTargetImage == nil else {
                return
            }
            
            // 比较当前显示图像与实际封面
            if self.displayImage != self.coverImage {
                self.pendingTargetImage = self.coverImage
                self.startAnimatedTransition(immediately: true)
            }
        }
    }
    
    // MARK: - 取消一致性检查
    private func cancelConsistencyCheckTimer() {
        consistencyCheckTimerID = nil
    }
    
    // MARK: - 计时器管理
    private func cancelDebounceTimer() {
        debounceTimerID = nil
    }
}

extension UIImage {
    static func == (lhs: UIImage, rhs: UIImage) -> Bool {
        return lhs.pngData() == rhs.pngData()
    }
}
