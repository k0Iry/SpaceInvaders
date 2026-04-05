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
    private let bitmapProducer: BitmapProducer

    init() {
        let cpuController = CpuController()
        self.cpuController = cpuController
        self.bitmapProducer = cpuController.bitmapProducer
    }

    var body: some Scene {
        WindowGroup {
            InvadersView(bitmapProducer: bitmapProducer)
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
