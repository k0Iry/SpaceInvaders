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
    @StateObject private var bitmapProducer: BitmapProducer

    init() {
        let cpuController = CpuController()
        self.cpuController = cpuController
        _bitmapProducer = StateObject(wrappedValue: cpuController.bitmapProducer)
    }

    var body: some Scene {
        WindowGroup {
            InvadersView(bitmapImage: $bitmapProducer.bitmapImage)
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
