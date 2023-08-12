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
    @Binding public private(set) var bitmapImage: CGImage?
    
    var body: some View {
        VStack {
            if let image = bitmapImage {
                Image(image, scale: 1.0, label: Text("Invaders"))
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(CGSize(width: CGFloat(width), height: CGFloat(height)), contentMode: .fit)
            }
        }
    }
}


