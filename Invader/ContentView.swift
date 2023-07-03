//
//  ContentView.swift
//  Invader
//
//  Created by xintu on 6/19/23.
//

import SwiftUI

private let width = 224
private let height = 256

class DisplayLink: ObservableObject {
    private let ram: UnsafePointer<UInt8>
    
    private let drawingBuffer: UnsafeMutablePointer<UInt8>
    
    private var displayLink: CVDisplayLink?
    
    @Published var image: CGImage?
    
    init(ram: UnsafePointer<UInt8>) {
        self.ram = ram
        self.drawingBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height)
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        CVDisplayLinkSetOutputHandler(displayLink!, { (displayLink, timestamp, timestamp1, options, flags ) in
            let image = self.drawImage(drawingBuffer: self.drawingBuffer)
            DispatchQueue.main.async {
                self.image = image
            }
            return kCVReturnSuccess
        })
    }
    
    func startRefreshing() {
        CVDisplayLinkStart(displayLink!)
    }
    
    private func drawImage(drawingBuffer: UnsafeMutablePointer<UInt8>) -> CGImage? {
        let frameBuffer = self.ram.advanced(by: 0x400)
        for i in 0..<width {
            for j in stride(from: 0, to: height, by: 8) {
                let pixel = frameBuffer[i * height / 8 + j / 8]
                let offset = (height - 1 - j) * width + i
                var ptr = drawingBuffer.advanced(by: offset)
                for p in 0..<8 {
                    let rgb: UInt8 = (pixel & (1 << p)) != 0 ? 0xff : 0
                    ptr.pointee = rgb
                    ptr -= width
                }
            }
        }
        let bitmapContext = CGContext(data: drawingBuffer, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        return bitmapContext?.makeImage()
    }
    
    func stopRefreshing() {
        CVDisplayLinkStop(displayLink!)
    }
}

struct ContentView: View {
    
    @StateObject private var imageUpdate: DisplayLink
    
    @State private var start = false
    @State private var buttonTitle = "Start"
    
    private let notifyInterruptCallback: (UInt32) -> Void
    
    init(imageUpdate: DisplayLink, callback: @escaping (UInt32) -> Void) {
        _imageUpdate = StateObject(wrappedValue: imageUpdate)
        self.notifyInterruptCallback = callback
    }
    
    var body: some View {
        VStack {
            if let image = imageUpdate.image {
                Image(image, scale: 1.0, label: Text(".."))
            }
            Button(buttonTitle, action: {
                if !start {
                    imageUpdate.startRefreshing()
                    notifyInterruptCallback(1)
                    buttonTitle = "Stop"
                } else {
                    imageUpdate.stopRefreshing()
                    notifyInterruptCallback(0)
                    buttonTitle = "Start"
                }
                start = !start
                pause_start_execution()
            })
        }
    }
}



