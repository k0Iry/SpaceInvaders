//
//  Cpu.swift
//  Invader
//
//  Created by xintu on 6/27/23.
//

import Foundation
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#else
import CoreGraphics
import CoreVideo
#endif

final private class IoObject: IoModelProtocol {
    private var shift0: UInt8 = 0 // lower  8 bits of 16-bits word on screen
    private var shift1: UInt8 = 0 // higher 8 bits of 16-bits word on screen
    private var shift_offset: UInt8 = 0 // Writing to port 2 (bits 0,1,2) sets the offset for the 8 bit result
    var inport1: UInt8 = 0 // we only do 1 player for now...
    
    func input(port: UInt8) -> UInt8 {
        var ret: UInt8 = 0
        switch port {
        case 1:
            return inport1
        case 3:
            let v: UInt16 = UInt16(shift1) << 8 | UInt16(shift0)
            ret = UInt8(truncatingIfNeeded: v >> (8 - shift_offset))
        default:
            break
        }
        return ret
    }
    
    func output(port: UInt8, value: UInt8) {
        switch port {
        case 2:
            shift_offset = value & 0x7 // shift amount (3 bits)
        case 4:
            shift0 = shift1
            shift1 = value
            // port 3, 5 are for sounds currently not supported yet
        default:
            break
        }
    }
}

private func input_callback(io_object: UnsafeRawPointer!, port: UInt8) -> UInt8 {
    let ioObject = io_object.bindMemory(to: IoObject.self, capacity: 1).pointee
    return ioObject.input(port: port)
}

private func output_callback(io_object: UnsafeRawPointer!, port: UInt8, value: UInt8) {
    let ioObject = io_object.bindMemory(to: IoObject.self, capacity: 1).pointee
    ioObject.output(port: port, value: value)
}

protocol KeyInputControlDelegate {
    func press(_ action: Action)
    func release(_ action: Action)
}

// macOS keycodes: https://stackoverflow.com/a/69908491/6289529
enum Action: UInt16 {
    case start = 1
    case coin = 8
    case pause = 35
    case fire = 49
    case left = 123
    case right = 124
    case restart = 15
}

final class CpuController: KeyInputControlDelegate, ObservableObject {
    private let cpu: OpaquePointer
    
    private let sender: UnsafeMutableRawPointer
    
    let interruptTimerQueue = DispatchQueue(label: "me.kljsandjb.interrupt")
    private var interruptTimer: DispatchSourceTimer?
    private var shouldDeliveryInterrupt = false
    
    // vblank interrupt signal, 1 means half screen rendering, 2 means full screen
    private var vblankInterrupt: UInt8 = 1
    
    // CVDisplayLink for publishing the bitmap calculated from vram buffer
#if os(iOS) || os(tvOS) || os(watchOS)
    private var displayLink: CADisplayLink?
#else
    private var displayLink: CVDisplayLink?
#endif
    private let drawingBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height)
    
    private let ram: UnsafePointer<UInt8>
    
    private var ioObject = IoObject()
    
    @Published var bitmapImage: CGImage?
    
    init() {
        let callbacks = IoCallbacks(input: input_callback, output: output_callback)
        let path = Bundle.main.path(forResource: "invaders", ofType: nil)
        let resources = new_cpu_instance(path, 8192, callbacks, &ioObject)
        self.cpu = resources.cpu
        self.sender = resources.sender
        self.ram = get_ram(self.cpu)
#if os(macOS)
        setupDisplayLink()
#endif
        setupInterruptTimer()
        Thread {
            run(self.cpu, self.sender)
        }.start()
    }
    
#if os(macOS)
    private func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        CVDisplayLinkSetOutputHandler(displayLink!) { (displayLink, timestamp, timestamp1, options, flags) in
            let image = drawBitmapImage(frameBuffer: self.ram.advanced(by: 0x400), drawingBuffer: self.drawingBuffer)
            DispatchQueue.main.async {
                self.bitmapImage = image
            }
            return kCVReturnSuccess
        }
    }
#endif
    
    private func setupInterruptTimer() {
        interruptTimer = DispatchSource.makeTimerSource(queue: interruptTimerQueue)
#if os(iOS) || os(tvOS) || os(watchOS)
        interruptTimer?.schedule(deadline: .now(), repeating: Double(1.0/120))
#else
        interruptTimer?.schedule(deadline: .now(), repeating: Double(1.0/CGDisplayCopyDisplayMode(CGMainDisplayID())!.refreshRate))
#endif
        interruptTimer?.setEventHandler {
            send_message(self.sender, Message(tag: Interrupt, .init(interrupt: .init(irq_no: self.vblankInterrupt, allow_nested_interrupt: false))))
            self.vblankInterrupt = self.vblankInterrupt == 1 ? 2 : 1
        }
    }
    
    private func enableInterrupt(_ enable: Bool) {
        if enable {
            interruptTimer?.resume()
        } else {
            interruptTimer?.suspend()
        }
    }
    
    private func enableDisplayLink(_ enable: Bool) {
        if enable {
#if os(iOS) || os(tvOS) || os(watchOS)
            displayLink = CADisplayLink(target: self, selector: #selector(drawImage))
            displayLink?.add(to: RunLoop.main, forMode: .default)
#else
            CVDisplayLinkStart(displayLink!)
#endif
        } else {
#if os(iOS) || os(tvOS) || os(watchOS)
            displayLink?.remove(from: RunLoop.main, forMode: .default)
#else
            CVDisplayLinkStop(displayLink!)
#endif
        }
    }
    
    // KeyInputControlDelegate
    func press(_ action: Action) {
        switch action {
        case .restart: send_message(self.sender, Message(tag: Restart, .init()))
        case .pause:
            shouldDeliveryInterrupt = !shouldDeliveryInterrupt
            enableInterrupt(shouldDeliveryInterrupt)
            enableDisplayLink(shouldDeliveryInterrupt)
            send_message(self.sender, Message(tag: Suspend, .init()))
        case .coin: ioObject.inport1 |= 0x01
        case .start: ioObject.inport1 |= 0x04
        case .fire: ioObject.inport1 |= 0x10
        case .left: ioObject.inport1 |= 0x20
        case .right: ioObject.inport1 |= 0x40
        }
        
    }
    
    func release(_ action: Action) {
        switch action {
        case .coin: ioObject.inport1 &= ~0x01
        case .start: ioObject.inport1 &= ~0x04
        case .fire: ioObject.inport1 &= ~0x10
        case .left: ioObject.inport1 &= ~0x20
        case .right: ioObject.inport1 &= ~0x40
        default: break
        }
    }
    
    
#if os(iOS) || os(tvOS) || os(watchOS)
    @objc func drawImage(_ displayLink: CADisplayLink) -> Void {
        let frameBuffer = self.ram.advanced(by: 0x400)
        bitmapImage = drawBitmapImage(frameBuffer: frameBuffer, drawingBuffer: drawingBuffer)
    }
#endif
}

private func drawBitmapImage(frameBuffer: UnsafePointer<UInt8>, drawingBuffer: UnsafeMutablePointer<UInt8>) -> CGImage? {
    for i in 0..<width {
        for j in stride(from: 0, to: height, by: 8) {
            let pixel = frameBuffer[i * height / 8 + j / 8]
            let offset = (height - 1 - j) * width + i
            var ptr = drawingBuffer.advanced(by: offset)
            for p in 0..<8 {
                let monochrome: UInt8 = (pixel & (1 << p)) != 0 ? 0xff : 0
                ptr.pointee = monochrome
                ptr -= width
            }
        }
    }
    let bitmapContext = CGContext(data: drawingBuffer, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
    return bitmapContext?.makeImage()
}
