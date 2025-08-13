//
//  AudioPlayerViewModel.swift
//  Listening
//
//  Created by LittleSheep on 2025/8/13.
//

import SwiftUI
import Combine

class AudioPlayerViewModel: ObservableObject {
    @Published var currentTime: Double = 0
    @Published var totalTime: Double = 0
    @Published var progress: Float = 0
    @Published var isSeeking: Bool = false

    var audioPlayer: AudioPlayer // Assuming you have a class for your audio player
    var timer: Timer?

    init(audioPlayer: AudioPlayer) {
        self.audioPlayer = audioPlayer
    }

    func startUpdatingProgress() {
        // Invalidate any existing timer first
        timer?.invalidate()
        // Create a new timer that fires every 0.25 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, !self.isSeeking, let player = self.audioPlayer.player else { return }

            self.currentTime = min(player.currentTime, player.duration)
            self.totalTime = player.duration
            self.progress = min(1.0, Float(self.currentTime / self.totalTime))
        }
    }

    func stopUpdatingProgress() {
        timer?.invalidate()
        timer = nil
    }
}
