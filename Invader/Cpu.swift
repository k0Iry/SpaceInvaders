//
//  Cpu.swift
//  Invader
//
//  Created by xintu on 6/27/23.
//

import Foundation
import CoreGraphics

private var shift0: UInt8 = 0
private var shift1: UInt8 = 0
private var shift_offset: UInt8 = 0

private func input_callback(port: UInt8) -> UInt8 {
    var ret: UInt8 = 0
    switch port {
    case 0:
        return 1
    case 1:
        return 0
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
        shift_offset = value & 0x7
    case 4:
        shift0 = shift1
        shift1 = value
    default:
        break
    }
}

class CpuEngine: NSObject, PortDelegate {
    let cpu: OpaquePointer
    private var port: Port
    private static var interrupt: UInt8 = 1
    private var interruptTimer: Timer?
    override init() {
        let callbacks = IoCallbacks(input: input_callback(port:), output: output_callback(port:value:))
        let path = Bundle.main.path(forResource: "invaders", ofType: nil)
        self.cpu = new_cpu_instance(path, 8192, callbacks)!
        self.port = Port()
        super.init()
        self.port.setDelegate(self)
    }
    
    private static func startInterruptDeliveryTimer() -> Timer {
        Timer(timeInterval: 1.0/CGDisplayCopyDisplayMode(CGMainDisplayID())!.refreshRate, repeats: true) {_ in
            send_interrupt(interrupt, false)
            interrupt = interrupt == 1 ? 2 : 1
        }
    }
    
    internal func handle(_ message: PortMessage) {
        if message.msgid == 0 {
            if let interruptTimer = interruptTimer {
                interruptTimer.invalidate()
            }
        } else {
            interruptTimer = Self.startInterruptDeliveryTimer()
            RunLoop.current.add(interruptTimer!, forMode: RunLoop.Mode.common)
        }
    }
    
    func sendPortMessage(_ msgId: UInt32) {
        let message = PortMessage(send: self.port, receive: self.port, components: nil)
        message.msgid = msgId
        message.send(before: Date.now)
    }
    
    func start() {
        // thread for delivering the interrupts, using Port to control interrupt timer
        Thread {
            RunLoop.current.add(self.port, forMode: RunLoop.Mode.default)
            RunLoop.current.run()
        }.start()
        
        Thread {
            run(self.cpu)
        }.start()
    }
}
