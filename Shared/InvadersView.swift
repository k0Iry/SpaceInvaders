//
//  ContentView.swift
//  Invader
//
//  Created by xintu on 6/19/23.
//

import SwiftUI

let width = 224
let height = 256

struct InvadersView: View {
    
    @ObservedObject private var cpuController: CpuController
    
    init(cpuController: CpuController) {
        self.cpuController = cpuController
    }
    
    var body: some View {
        VStack {
            if let image = cpuController.bitmapImage {
                Image(image, scale: 1.0, label: Text("Invaders"))
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(CGSize(width: CGFloat(width), height: CGFloat(height)), contentMode: .fit)
            }
        }
    }
}


