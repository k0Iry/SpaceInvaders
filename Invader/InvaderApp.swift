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
    private let invaderView: ContentView
    init() {
        self.cpuController = CpuController()
        self.invaderView = ContentView(cpuController: cpuController)
        cpuController.start()
    }
    
    var body: some Scene {
        WindowGroup {
            invaderView
        }
    }
}
