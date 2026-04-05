//
//  Invader_iOSApp.swift
//  Invader-iOS
//
//  Created by xintu on 7/27/23.
//

import SwiftUI

@main
struct Invader_iOSApp: App {
    private let cpuController: CpuController
    @StateObject private var bitmapProducer: BitmapProducer

    init() {
        let cpuController = CpuController()
        self.cpuController = cpuController
        _bitmapProducer = StateObject(wrappedValue: cpuController.bitmapProducer)
    }

    var body: some Scene {
        WindowGroup {
            ControlPanel(keyInputDelegate: cpuController)
            InvadersView(bitmapImage: $bitmapProducer.bitmapImage)
            PlayControl(keyInputDelegate: cpuController)
        }
    }
}
