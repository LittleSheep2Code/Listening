import SwiftUI

// 用于收集歌词行距离的PreferenceKey
struct LineCenterDistancePreference: PreferenceKey {
    typealias Value = [LineDistanceData]
    static var defaultValue: Value = []
    
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.append(contentsOf: nextValue())
    }
}

struct LineDistanceData: Equatable {
    let index: Int
    let distance: CGFloat
}

struct LyricsDisplayView: View {
    let lyricContent: String
    let musicID: UUID
    @Binding var currentTime: TimeInterval
    @Binding var totalDuration: TimeInterval
    @Binding var curvature: Double
    @Binding var blur: Double
    @Binding var isCompact: Bool
    let panelCenterY: CGFloat // 从父视图接收的面板中心Y坐标
    
    @State private var parsedLyrics: [LyricLine] = []
    @State private var currentLineIndex: Int? = nil
    @State private var processor = LyricsProcessor()
    @State private var containerSize = CGSize.zero
    
    @EnvironmentObject private var audioPlayer: AudioPlayer
    
    var body: some View {
        VStack(spacing: 0) {
            // 歌词内容区域（带弯曲效果）
            GeometryReader { geometry in
                LyricsContent(
                    parsedLyrics: parsedLyrics,
                    currentLineIndex: currentLineIndex,
                    curvature: isCompact ? 0 : curvature,
                    blur: blur,
                    panelCenterY: panelCenterY,
                    onLyricTapped: handleLyricTap
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .position(x: geometry.size.width/2, y: geometry.size.height/2)
                .onAppear { containerSize = geometry.size }
            }
        }
        .onAppear(perform: parseLyrics)
        .onChange(of: lyricContent, initial: true) { _,_ in parseLyrics() }
        .onChange(of: currentTime, initial: true) { _,_ in updateHighlightedLine() }
        .clipped()
    }
    
    private func parseLyrics() {
        processor.processLyricsFile(for: musicID, content: lyricContent) { lines in
            parsedLyrics = lines
            updateHighlightedLine()
        }
    }
    
    private func updateHighlightedLine() {
        guard !parsedLyrics.isEmpty else {
            currentLineIndex = nil
            return
        }
        
        var index = 0
        while index < parsedLyrics.count - 1 {
            if currentTime < parsedLyrics[index].startTime {
                break
            }
            index += 1
        }
        
        index = max(0, index - 1)
        
        if index != currentLineIndex {
            currentLineIndex = index
        }
    }
    
    private func handleLyricTap(at index: Int) {
        guard index < parsedLyrics.count else { return }
        let targetTime = parsedLyrics[index].startTime
        audioPlayer.seek(to: targetTime / totalDuration)
        audioPlayer.play()
    }
}

// MARK: - 子视图

// 歌词内容视图
struct LyricsContent: View {
    let parsedLyrics: [LyricLine]
    let currentLineIndex: Int?
    let curvature: Double
    let blur: Double // 新增模糊参数
    let panelCenterY: CGFloat
    let onLyricTapped: (Int) -> Void
    
    @State private var distanceMap: [Int: CGFloat] = [:]
    @State private var closestLineIndex: Int? = nil
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .center, spacing: 30) {
                    Text(" ")
                    Text(" ")
                    ForEach(Array(parsedLyrics.enumerated()), id: \.element.id) { (index, lyric) in
                        CurvedLyricRow(
                            index: index,
                            lyric: lyric,
                            isCurrent: index == currentLineIndex,
                            isClosestToCenter: index == closestLineIndex,
                            curvature: curvature,
                            blur: blur,
                            panelCenterY: panelCenterY,
                            onTapped: { onLyricTapped(index) }
                        )
                        .id(index)
                    }
                    Text(" ")
                    Text(" ")
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 240)
                .padding(.bottom, 200)
            }
            .onChange(of: currentLineIndex, initial: true) { _,index in
                if let index = index {
                    withAnimation {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
                updateClosestLine()
            }
            .onPreferenceChange(LineCenterDistancePreference.self) { values in
                var updatedMap = distanceMap
                values.forEach { data in
                    updatedMap[data.index] = data.distance
                }
                distanceMap = updatedMap
                updateClosestLine()
            }
        }
        .scrollIndicators(.hidden)
    }
    
    // 更新最近行
    private func updateClosestLine() {
        guard !distanceMap.isEmpty else {
            closestLineIndex = nil
            return
        }
        
        if let closest = distanceMap.min(by: {
            abs($0.value) < abs($1.value)
        }) {
            closestLineIndex = closest.key
        } else {
            closestLineIndex = nil
        }
    }
}

// 弯曲歌词行

