//
//  Invader_iOSApp.swift
//  Invader-iOS
//
//  Created by xintu on 7/27/23.
//

import SwiftUI

@main
struct Invader_iOSApp: App {
    @StateObject private var bitmapProducer = CpuController().bitmapProducer
    var body: some Scene {
        WindowGroup {
            InvadersView(bitmapImage: $bitmapProducer.bitmapImage)
            ControlPanel(keyInputDelegate: bitmapProducer.keyInputDelegate!)
        }
    }
}
