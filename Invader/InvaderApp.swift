//
//  InvaderApp.swift
//  Invader
//
//  Created by xintu on 6/19/23.
//

import SwiftUI

@main
struct InvaderApp: App {
    @StateObject private var bitmapProducer = CpuController().bitmapProducer
    var body: some Scene {
        WindowGroup {
            InvadersView(bitmapImage: $bitmapProducer.bitmapImage).frame(minWidth: CGFloat(width), maxWidth: .infinity, minHeight: CGFloat(height), maxHeight: .infinity)
                .background(KeyEvents(keyInputControlDelegate: bitmapProducer.keyInputDelegate))
        }
    }
}
