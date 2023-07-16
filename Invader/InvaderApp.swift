//
//  InvaderApp.swift
//  Invader
//
//  Created by xintu on 6/19/23.
//

import SwiftUI

let width = 224
let height = 256

@main
struct InvaderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().frame(minWidth: CGFloat(width), maxWidth: .infinity, minHeight: CGFloat(height), maxHeight: .infinity)
        }
    }
}
