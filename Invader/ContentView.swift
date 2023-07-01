//
//  ContentView.swift
//  Invader
//
//  Created by xintu on 6/19/23.
//

import SwiftUI
import Combine

private let width = 224
private let height = 256

class TimerViewModel: ObservableObject {
    private let ram: UnsafePointer<UInt8>
    
    private let drawingBuffer: UnsafeMutablePointer<UInt8>
    
    private var timer: Timer?
    
    @Published var image: CGImage?
    
    init(ram: UnsafePointer<UInt8>) {
        self.ram = ram
        self.drawingBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height)
    }
    
    func startRefreshing() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60, repeats: true) { _ in
            self.image = self.drawImage(ram: self.ram, drawingBuffer: self.drawingBuffer)
        }
    }
    
    private func drawImage(ram: UnsafePointer<UInt8>, drawingBuffer: UnsafeMutablePointer<UInt8>) -> CGImage? {
        let frameBuffer = ram.advanced(by: 0x400)
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
        if let timer = timer {
            timer.invalidate()
            self.timer = nil
        }
    }
}

struct ContentView: View {
    
    @StateObject private var imageUpdate: TimerViewModel
    
    @State var start = false
    @State var buttonTitle = "Start"
    
    private let notifyInterruptCallback: (UInt32) -> Void
    
    init(imageUpdate: TimerViewModel, callback: @escaping (UInt32) -> Void) {
        _imageUpdate = StateObject(wrappedValue: imageUpdate)
        self.notifyInterruptCallback = callback
    }
    
    var body: some View {
        VStack {
            Image(size: CGSize(width: width, height: height)) { context in
                let bounds = CGRect(x: 0, y:0, width: width, height: height)
                if let image = imageUpdate.image {
                    context.draw(Image(image, scale: 1.0, label: Text("..")), in: bounds)
                }
            }
            Button(buttonTitle, action: {
                if !start {
                    imageUpdate.startRefreshing()
                    self.notifyInterruptCallback(1)
                    buttonTitle = "Stop"
                } else {
                    imageUpdate.stopRefreshing()
                    self.notifyInterruptCallback(0)
                    buttonTitle = "Start"
                }
                start = !start
                pause_start_execution()
            })
        }
    }
}



