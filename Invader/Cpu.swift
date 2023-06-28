//
//  Cpu.swift
//  Invader
//
//  Created by xintu on 6/27/23.
//

import Foundation


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

class CpuEngine {
    let cpu: OpaquePointer
    private var interrupt: UInt8 = 1
    init() {
        let callbacks = IoCallbacks(input: input_callback(port:), output: output_callback(port:value:))
        let path = Bundle.main.path(forResource: "invaders", ofType: nil)
        self.cpu = new_cpu_instance(path, 8192, callbacks)!
    }
    
    func start() {
        // thread for delivering the interrupts
        Thread {
            let timer = Timer(timeInterval: 1.0/60, repeats: true) {_ in
                send_interrupt(self.interrupt, false)
                self.interrupt = self.interrupt == 1 ? 2 : 1
            }
            RunLoop.current.add(timer, forMode: RunLoop.Mode.common)
            RunLoop.current.run()
        }.start()
        
        Thread {
            run(self.cpu)
        }.start()
    }
}
