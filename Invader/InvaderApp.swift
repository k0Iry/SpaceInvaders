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
    init() {
        self.cpuEngine = CpuEngine()
        cpuEngine.start()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(imageUpdate: TimerViewModel(ram: get_ram(cpuEngine.cpu)), callback: cpuEngine.sendPortMessage)
        }
    }
}
