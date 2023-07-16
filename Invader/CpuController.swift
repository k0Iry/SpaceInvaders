//
//  Cpu.swift
//  Invader
//
//  Created by xintu on 6/27/23.
//

import Foundation
import CoreGraphics
import CoreVideo

private var shift0: UInt8 = 0 // lower  8 bits of 16-bits word on screen
private var shift1: UInt8 = 0 // higher 8 bits of 16-bits word on screen
private var shift_offset: UInt8 = 0 // Writing to port 2 (bits 0,1,2) sets the offset for the 8 bit result
private var inport1: UInt8 = 0 // we only do 1 player for now...

private func input_callback(port: UInt8) -> UInt8 {
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

private func output_callback(port: UInt8, value: UInt8) {
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

protocol KeyInputControlDelegate {
    func keyUp(with keyCode: UInt16)
    func keyDown(with keyCode: UInt16)
}

final class CpuController: NSObject, PortDelegate, KeyInputControlDelegate, ObservableObject {
    private let cpu: OpaquePointer
    
    // mach port for controlling the timer which delivers interrupt signals
    private var port = Port()
    private var interruptTimer: Timer?
    private var shouldDeliveryInterrupt = false
    
    // vblank interrupt signal, 1 means half screen rendering, 2 means full screen
    private var vblankInterrupt: UInt8 = 1
    
    // CVDisplayLink for publishing the bitmap calculated from vram buffer
    private var displayLink: CVDisplayLink?
    private let drawingBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height)
    
    private let ram: UnsafePointer<UInt8>
    
    @Published var bitmapImage: CGImage?
    
    override init() {
        let callbacks = IoCallbacks(input: input_callback(port:), output: output_callback(port:value:))
        let path = Bundle.main.path(forResource: "invaders", ofType: nil)
        self.cpu = new_cpu_instance(path, 8192, callbacks)!
        self.ram = get_ram(self.cpu)
        super.init()
        self.port.setDelegate(self)
        // setup refreshing callbacks
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        CVDisplayLinkSetOutputHandler(displayLink!) { (displayLink, timestamp, timestamp1, options, flags ) in
            let image = drawImage(frameBuffer: self.ram.advanced(by: 0x400), drawingBuffer: self.drawingBuffer)
            DispatchQueue.main.async {
                self.bitmapImage = image
            }
            return kCVReturnSuccess
        }
    }
    
    private func interruptDeliveryTimer() -> Timer {
        Timer(timeInterval: 1.0/CGDisplayCopyDisplayMode(CGMainDisplayID())!.refreshRate, repeats: true) {_ in
            send_interrupt(self.vblankInterrupt, false)
            self.vblankInterrupt = self.vblankInterrupt == 1 ? 2 : 1
        }
    }
    
    internal func handle(_ message: PortMessage) {
        if message.msgid == 0 {
            interruptTimer!.invalidate()
        } else {
            interruptTimer = interruptDeliveryTimer()
            RunLoop.current.add(interruptTimer!, forMode: RunLoop.Mode.common)
        }
    }
    
    private func enableInterrupt(_ command: UInt32) {
        let message = PortMessage(send: port, receive: port, components: nil)
        message.msgid = command
        message.send(before: Date.now)
    }
    
    // KeyInputControl, macOS keycodes: https://stackoverflow.com/a/69908491/6289529
    private enum KeyMap: UInt16 {
        case start = 1
        case coin = 8
        case pause = 35
        case fire = 49
        case left = 123
        case right = 124
    }
    
    func keyUp(with keyCode: UInt16) {
        switch KeyMap(rawValue: keyCode) {
        case .coin: inport1 &= ~0x01
        case .start: inport1 &= ~0x04
        case .left: inport1 &= ~0x20
        case .right: inport1 &= ~0x40
        case .fire: inport1 &= ~0x10
        default: break
        }
    }
    
    func keyDown(with keyCode: UInt16) {
        switch KeyMap(rawValue: keyCode) {
        case .coin: inport1 |= 0x01
        case .start: inport1 |= 0x04
        case .left: inport1 |= 0x20
        case .right: inport1 |= 0x40
        case .fire: inport1 |= 0x10
        case .pause: shouldDeliveryInterrupt = !shouldDeliveryInterrupt
            if shouldDeliveryInterrupt {
                enableInterrupt(1)
                CVDisplayLinkStart(displayLink!)
            } else {
                enableInterrupt(0)
                CVDisplayLinkStop(displayLink!)
            }
            pause_start_execution()
        default: break
        }
    }
    
    func start() -> Self {
        Thread {
            RunLoop.current.add(self.port, forMode: RunLoop.Mode.default)
            RunLoop.current.run()
        }.start()
        
        Thread {
            run(self.cpu)
        }.start()
        return self
    }
}

private func drawImage(frameBuffer: UnsafePointer<UInt8>, drawingBuffer: UnsafeMutablePointer<UInt8>) -> CGImage? {
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
