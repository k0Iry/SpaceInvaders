//
//  InvaderApp.swift
//  Invader
//
//  Created by xintu on 6/19/23.
//

import SwiftUI

@main
struct InvaderApp: App {
    private let cpuController: CpuController
    private let videoFramePipeline: VideoFramePipeline

    init() {
        let cpuController = CpuController()
        self.cpuController = cpuController
        self.videoFramePipeline = cpuController.videoFramePipeline
    }

    var body: some Scene {
        WindowGroup {
            InvadersView(videoFramePipeline: videoFramePipeline)
                .frame(
                    minWidth: CGFloat(width),
                    maxWidth: .infinity,
                    minHeight: CGFloat(height),
                    maxHeight: .infinity
                )
                .background(KeyEvents(keyInputControlDelegate: cpuController))
        }
    }
}
