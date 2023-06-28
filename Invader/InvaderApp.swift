//
//  InvaderApp.swift
//  Invader
//
//  Created by xintu on 6/19/23.
//

import SwiftUI

@main
struct InvaderApp: App {
    let cpuEngine: CpuEngine
    let drawingBuffer: UnsafeMutablePointer<UInt8>
    init() {
        self.cpuEngine = CpuEngine()
        self.drawingBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4 * 224 * 256)
        cpuEngine.start()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(ram: get_ram(cpuEngine.cpu), drawingBuffer: drawingBuffer)
        }
    }
}
