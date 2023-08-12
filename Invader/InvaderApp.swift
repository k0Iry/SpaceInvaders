//
//  InvaderApp.swift
//  Invader
//
//  Created by xintu on 6/19/23.
//

import SwiftUI

@main
struct InvaderApp: App {
    @StateObject private var cpuController = CpuController()
    var body: some Scene {
        WindowGroup {
            InvadersView(bitmapImage: $cpuController.bitmapImage).frame(minWidth: CGFloat(width), maxWidth: .infinity, minHeight: CGFloat(height), maxHeight: .infinity)
                .background(KeyEvents(keyInputControlDelegate: cpuController))
        }
    }
}
