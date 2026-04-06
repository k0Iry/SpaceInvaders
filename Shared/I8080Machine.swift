import Foundation

enum MachineSliceResult {
    case running
    case halted
    case fault(I8080Status)
}

final class I8080Machine {
    private static let cpuClockHz: UInt64 = 2_000_000
    private static let interruptRateHz: UInt64 = 120
    private static let baseCyclesPerInterrupt = cpuClockHz / interruptRateHz
    private static let leftoverCyclesPerSecond = cpuClockHz % interruptRateHz

    private let lock = NSLock()
    private let cpuStorage: UnsafeMutableRawPointer
    private let cpu: OpaquePointer
    private let romStorage: UnsafeMutablePointer<UInt8>
    private let romLength: Int
    private let ramStorage: UnsafeMutablePointer<UInt8>
    private let ramLength: Int

    private var vblankInterrupt: UInt8 = 1
    private var cycleRemainderAccumulator: UInt64 = 0

    var videoRAM: UnsafePointer<UInt8> {
        UnsafePointer(ramStorage.advanced(by: 0x400))
    }

    init(romData: Data, ramLength: Int = 8192) {
        self.romLength = romData.count
        self.romStorage = UnsafeMutablePointer<UInt8>.allocate(capacity: max(romData.count, 1))
        _ = romData.copyBytes(
            to: UnsafeMutableBufferPointer(start: romStorage, count: romData.count)
        )

        self.ramLength = ramLength
        self.ramStorage = UnsafeMutablePointer<UInt8>.allocate(capacity: ramLength)
        self.ramStorage.initialize(repeating: 0, count: ramLength)

        self.cpuStorage = UnsafeMutableRawPointer.allocate(
            byteCount: Int(i8080_cpu_size()),
            alignment: Int(i8080_cpu_align())
        )

        var cpuPointer: OpaquePointer? = nil
        let initStatus = i8080_init_cpu(
            cpuStorage,
            romStorage,
            romData.count,
            ramStorage,
            ramLength,
            &cpuPointer
        )
        guard initStatus == I8080Status_Ok, let cpuPointer else {
            fatalError("Failed to initialize CPU: \(initStatus.rawValue)")
        }
        self.cpu = cpuPointer
    }

    deinit {
        lock.withLock {
            _ = i8080_deinit_cpu(cpu)
        }
        cpuStorage.deallocate()
        ramStorage.deinitialize(count: ramLength)
        ramStorage.deallocate()
        romStorage.deinitialize(count: max(romLength, 1))
        romStorage.deallocate()
    }

    func restart() {
        lock.withLock {
            _ = i8080_restart(cpu)
            vblankInterrupt = 1
            cycleRemainderAccumulator = 0
        }
    }

    func runVBlankSlice(io: IoModelProtocol) -> MachineSliceResult {
        let targetCycles = nextInterruptCycleBudget()
        let sliceStart = DispatchTime.now().uptimeNanoseconds
        var cyclesExecuted: UInt64 = 0

        while cyclesExecuted < targetCycles {
            var result = I8080StepResult(
                cycles: 0,
                state: I8080ExecutionState_Continue,
                port: 0,
                value: 0
            )
            let status = lock.withLock {
                i8080_step(cpu, &result)
            }
            guard status == I8080Status_Ok else {
                return .fault(status)
            }

            cyclesExecuted &+= result.cycles

            switch result.state {
            case I8080ExecutionState_Input:
                let input = io.input(port: result.port)
                let inputStatus = lock.withLock {
                    i8080_provide_input(cpu, input)
                }
                guard inputStatus == I8080Status_Ok else {
                    return .fault(inputStatus)
                }
            case I8080ExecutionState_Output:
                io.output(port: result.port, value: result.value)
            case I8080ExecutionState_Halted:
                paceSlice(sliceStart: sliceStart, cyclesExecuted: max(cyclesExecuted, 1))
                return .halted
            default:
                break
            }
        }

        let interruptStatus = lock.withLock {
            let status = i8080_interrupt(cpu, vblankInterrupt)
            if status == I8080Status_Ok {
                vblankInterrupt = vblankInterrupt == 1 ? 2 : 1
            }
            return status
        }
        guard interruptStatus == I8080Status_Ok else {
            return .fault(interruptStatus)
        }

        paceSlice(sliceStart: sliceStart, cyclesExecuted: cyclesExecuted)
        return .running
    }

    private func nextInterruptCycleBudget() -> UInt64 {
        var cycles = Self.baseCyclesPerInterrupt
        cycleRemainderAccumulator += Self.leftoverCyclesPerSecond
        if cycleRemainderAccumulator >= Self.interruptRateHz {
            cycles += 1
            cycleRemainderAccumulator -= Self.interruptRateHz
        }
        return cycles
    }

    private func paceSlice(sliceStart: UInt64, cyclesExecuted: UInt64) {
        let elapsed = DispatchTime.now().uptimeNanoseconds - sliceStart
        let targetDuration = max(
            UInt64(1),
            (cyclesExecuted * 1_000_000_000) / Self.cpuClockHz
        )
        if elapsed < targetDuration {
            Thread.sleep(forTimeInterval: Double(targetDuration - elapsed) / 1_000_000_000)
        }
    }
}
