//
//  InvaderApp.swift
//  Invader
//
//  Created by xintu on 6/19/23.
//

import SwiftUI

@main
struct InvaderApp: App {
    var cpuEngine: CpuEngine
    var buffer: UnsafeMutablePointer<UInt8>
    init() {
        self.cpuEngine = CpuEngine()
        self.buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4 * 224 * 256)
        cpuEngine.start()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(frameBuffer: get_ram(self.cpuEngine.cpu), buffer: self.buffer)
        }
    }
}
