//
//  ListeningApp.swift
//  Listening
//
//  Created by LittleSheep on 2025/8/12.
//

import SwiftUI

@main
struct ListeningApp: App {
    init() {
        // 初始化全局管理器
        _ = GlobalMusicManager.shared
        _ = PlaylistManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
