//
//  InvaderApp.swift
//  Invader
//
//  Created by xintu on 6/19/23.
//

import SwiftUI

@main
struct InvaderApp: App {
    private let cpuEngine: CpuEngine
    private let invaderView: ContentView
    init() {
        self.cpuEngine = CpuEngine()
        self.invaderView = ContentView(imageUpdate: DisplayLink(ram: get_ram(cpuEngine.cpu)), interruptControlDelegate: cpuEngine, keyInputControlDelegate: cpuEngine)
        cpuEngine.start()
    }
    
    var body: some Scene {
        WindowGroup {
            invaderView
        }
    }
}
