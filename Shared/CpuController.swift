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
    private var inport1: UInt8 = 0 // we only do 1 player for now...
    
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
    
    internal func perform(_ action: Action) {
        switch action {
        case .coin: inport1 |= 0x01
        case .start: inport1 |= 0x04
        case .fire: inport1 |= 0x10
        case .left: inport1 |= 0x20
        case .right: inport1 |= 0x40
        default: break
        }
    }
    
    internal func withdraw(_ action: Action) {
        switch action {
        case .coin: inport1 &= ~0x01
        case .start: inport1 &= ~0x04
        case .fire: inport1 &= ~0x10
        case .left: inport1 &= ~0x20
        case .right: inport1 &= ~0x40
        default: break
        }
    }
}

protocol KeyInputControlDelegate: AnyObject {
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

final class CpuController: KeyInputControlDelegate {
    private let cpu: OpaquePointer
    
    private let sender: UnsafeMutableRawPointer
    
    private let interruptTimerQueue = DispatchQueue(label: "me.kljsandjb.interrupt")
    private var interruptTimer: DispatchSourceTimer?
    private var isRunning = false
    
    // vblank interrupt signal, 1 means half screen rendering, 2 means full screen
    private var vblankInterrupt: UInt8 = 1
    
    private let ram: UnsafePointer<UInt8>
    
    var bitmapProducer: BitmapProducer
    
    private var ioObject = IoObject()
    
    init() {
        let callbacks = IoCallbacks(input: {io_object, port in
            let ioObject = io_object?.bindMemory(to: IoObject.self, capacity: 1).pointee
            return ioObject!.input(port: port)
        }, output: {io_object, port, value in
            let ioObject = io_object?.bindMemory(to: IoObject.self, capacity: 1).pointee
            ioObject?.output(port: port, value: value)
        })
        let path = Bundle.main.path(forResource: "invaders", ofType: nil)
        let resources = withUnsafeBytes(of: &ioObject) {
            return new_cpu_instance(path, 8192, callbacks, $0.baseAddress!)
        }
        self.cpu = resources.cpu
        self.sender = resources.sender
        self.ram = get_ram(cpu)
        self.bitmapProducer = BitmapProducer(frameBuffer: ram.advanced(by: 0x400))
        self.bitmapProducer.keyInputDelegate = self
        setupInterruptTimer()
        Thread {
            run(self.cpu, self.sender)
        }.start()
    }
    
    private func setupInterruptTimer() {
        interruptTimer = DispatchSource.makeTimerSource(queue: interruptTimerQueue)
        interruptTimer?.schedule(deadline: .now(), repeating: Double(1.0/120))
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
    
    // KeyInputControlDelegate
    func press(_ action: Action) {
        switch action {
        case .restart: send_message(self.sender, Message(tag: Restart, .init()))
        case .pause:
            isRunning = !isRunning
            enableInterrupt(isRunning)
            bitmapProducer.enableDisplayLink(isRunning)
            send_message(self.sender, Message(tag: Suspend, .init()))
        default: ioObject.perform(action)
        }
    }
    
    func release(_ action: Action) {
        ioObject.withdraw(action)
    }
}

final internal class BitmapProducer: ObservableObject {
    // CVDisplayLink/CADisplayLink for publishing the bitmap calculated from vram buffer
#if os(iOS) || os(tvOS) || os(watchOS)
    private var displayLink: CADisplayLink?
#else
    private var displayLink: CVDisplayLink?
#endif
    private let drawingBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height)
    
    private let frameBuffer: UnsafePointer<UInt8>
    
    internal weak var keyInputDelegate: KeyInputControlDelegate?
    
    @Published var bitmapImage: CGImage?
    
#if os(macOS)
    private func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        CVDisplayLinkSetOutputHandler(displayLink!) { (_, _, _, _, _) in
            self.drawBitmapImage()
            return kCVReturnSuccess
        }
    }
#endif
    
    internal func enableDisplayLink(_ enable: Bool) {
        if enable {
#if os(iOS) || os(tvOS) || os(watchOS)
            displayLink = CADisplayLink(target: self, selector: #selector(drawBitmapImage))
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
    
    init(frameBuffer: UnsafePointer<UInt8>) {
        self.frameBuffer = frameBuffer
#if os(macOS)
        setupDisplayLink()
#endif
    }
    
    deinit {
        drawingBuffer.deallocate()
    }
    
    @objc private func drawBitmapImage() {
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
        let bitmapImage = bitmapContext?.makeImage()
#if os(macOS)
        DispatchQueue.main.async {
            self.bitmapImage = bitmapImage
        }
#else
        self.bitmapImage = bitmapImage
#endif
    }
}
