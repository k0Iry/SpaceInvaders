//
//  Invader_iOSApp.swift
//  Invader-iOS
//
//  Created by xintu on 7/27/23.
//

import SwiftUI

@main
struct Invader_iOSApp: App {
    private let cpuController = CpuController()
    
    var body: some Scene {
        WindowGroup {
            InvadersView(cpuController: cpuController)
            ControlPanel(keyInputDelegate: cpuController)
        }
    }
}
