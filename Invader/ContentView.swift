//
//  ContentView.swift
//  Invader
//
//  Created by xintu on 6/19/23.
//

import SwiftUI

struct ContentView: View {
    @State var image: CGImage? = nil
    
    let ram: UnsafePointer<UInt8>
    
    let drawingBuffer: UnsafeMutablePointer<UInt8>

    init(ram: UnsafePointer<UInt8>, drawingBuffer: UnsafeMutablePointer<UInt8>) {
        self.ram = ram
        self.drawingBuffer = drawingBuffer
    }
    
    var body: some View {
        Image(size: CGSize(width: 224, height: 256)) { context in
            let bounds = CGRect(x: 0, y:0, width: 224, height: 256)
            if let image = image {
                context.draw(Image(image, scale: 1.0, label: Text("..")), in: bounds)
            }
        }.onReceive(Timer.publish(every: 1.0/60, on: .main, in: .common).autoconnect(), perform: {_ in
            image = drawImage(ram: ram, drawingBuffer: drawingBuffer)
        })
    }
}

func drawImage(ram: UnsafePointer<UInt8>, drawingBuffer: UnsafeMutablePointer<UInt8>) -> CGImage? {
    let frameBuffer = ram.advanced(by: 0x400)
    for i in 0...224 {
        for j in stride(from: 0, to: 256, by: 8) {
            let pixel = frameBuffer[i * 32 + j / 8]
            let offset = (255 - j) * 224 * 4 + i * 4
            var ptr = drawingBuffer.advanced(by: offset)
            for p in 0...8 {
                let rgb: UInt8 = (pixel & (1 << p)) != 0 ? 0xff : 0
                ptr.pointee = rgb
                (ptr + 1).pointee = rgb
                (ptr + 2).pointee = rgb
                (ptr + 3).pointee = rgb
                ptr -= 224 * 4
            }
        }
    }
    let bitmapContext = CGContext(data: UnsafeMutableRawPointer(drawingBuffer), width: 224, height: 256, bitsPerComponent: 8, bytesPerRow: 224 * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
    let image = bitmapContext?.makeImage()
    return image
}

