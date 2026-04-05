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
    private var shift0: UInt8 = 0
    private var shift1: UInt8 = 0
    private var shiftOffset: UInt8 = 0
    private var inport1: UInt8 = 0

    func input(port: UInt8) -> UInt8 {
        switch port {
        case 1:
            return inport1
        case 3:
            let value = UInt16(shift1) << 8 | UInt16(shift0)
            return UInt8(truncatingIfNeeded: value >> (8 - shiftOffset))
        default:
            return 0
        }
    }

    func output(port: UInt8, value: UInt8) {
        switch port {
        case 2:
            shiftOffset = value & 0x7
        case 4:
            shift0 = shift1
            shift1 = value
        default:
            break
        }
    }

    func perform(_ action: Action) {
        switch action {
        case .coin: inport1 |= 0x01
        case .start: inport1 |= 0x04
        case .fire: inport1 |= 0x10
        case .left: inport1 |= 0x20
        case .right: inport1 |= 0x40
        default: break
        }
    }

    func withdraw(_ action: Action) {
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

enum Action: UInt16 {
    case start = 1
    case coin = 8
    case pause = 35
    case fire = 49
    case left = 123
    case right = 124
    case restart = 15
}

enum DisplayRefreshMode {
    case original60
    case deviceMaximum

#if os(iOS) || os(tvOS) || os(watchOS)
    func preferredFrameRateRange() -> CAFrameRateRange {
        switch self {
        case .original60:
            return CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        case .deviceMaximum:
            let maximum = Float(max(60, UIScreen.main.maximumFramesPerSecond))
            return CAFrameRateRange(minimum: 60, maximum: maximum, preferred: maximum)
        }
    }

    func fallbackFramesPerSecond() -> Int {
        switch self {
        case .original60:
            return 60
        case .deviceMaximum:
            return max(60, UIScreen.main.maximumFramesPerSecond)
        }
    }
#endif
}

final class CpuController: KeyInputControlDelegate {
    private let machine: I8080Machine
    private let stateLock = NSLock()
    private var isRunning = false
    private var shouldStop = false
    private let ioObject = IoObject()

    var bitmapProducer: BitmapProducer

    init(refreshMode: DisplayRefreshMode = .original60) {
        guard let romURL = Bundle.main.url(forResource: "invaders", withExtension: nil),
              let romData = try? Data(contentsOf: romURL)
        else {
            fatalError("Failed to load invaders ROM from app bundle")
        }

        self.machine = I8080Machine(romData: romData)
        self.bitmapProducer = BitmapProducer(frameBuffer: machine.frameBuffer, refreshMode: refreshMode)
        self.bitmapProducer.keyInputDelegate = self

        Thread { [weak self] in
            self?.cpuLoop()
        }.start()
    }

    deinit {
        stateLock.withLock {
            shouldStop = true
            isRunning = false
        }
    }

    private func cpuLoop() {
        while true {
            let (running, stopping) = stateLock.withLock {
                (isRunning, shouldStop)
            }

            if stopping {
                return
            }

            guard running else {
                Thread.sleep(forTimeInterval: 0.001)
                continue
            }

            switch machine.runInterruptSlice(io: ioObject) {
            case .running:
                break
            case .halted:
                stateLock.withLock {
                    isRunning = false
                }
                bitmapProducer.enableDisplayLink(false)
            case .fault(let status):
                assertionFailure("CPU slice failed with status \(status.rawValue)")
                stateLock.withLock {
                    isRunning = false
                }
                bitmapProducer.enableDisplayLink(false)
                Thread.sleep(forTimeInterval: 0.001)
            }
        }
    }

    func press(_ action: Action) {
        switch action {
        case .restart:
            machine.restart()
        case .pause:
            let nowRunning = stateLock.withLock {
                isRunning.toggle()
                return isRunning
            }
            bitmapProducer.enableDisplayLink(nowRunning)
        default:
            ioObject.perform(action)
        }
    }

    func release(_ action: Action) {
        ioObject.withdraw(action)
    }
}

final internal class BitmapProducer: ObservableObject {
#if os(iOS) || os(tvOS) || os(watchOS)
    private var displayLink: CADisplayLink?
#else
    private var displayLink: CVDisplayLink?
#endif
    private let drawingBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height)
    private let frameBuffer: UnsafePointer<UInt8>
    private let colorSpace = CGColorSpaceCreateDeviceGray()
    private let bitmapContext: CGContext?
    private let refreshMode: DisplayRefreshMode

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
            guard displayLink == nil else { return }
            let displayLink = CADisplayLink(target: self, selector: #selector(drawBitmapImage))
            if #available(iOS 15.0, tvOS 15.0, watchOS 8.0, *) {
                displayLink.preferredFrameRateRange = refreshMode.preferredFrameRateRange()
            } else {
                displayLink.preferredFramesPerSecond = refreshMode.fallbackFramesPerSecond()
            }
            displayLink.add(to: RunLoop.main, forMode: .common)
            self.displayLink = displayLink
#else
            CVDisplayLinkStart(displayLink!)
#endif
        } else {
#if os(iOS) || os(tvOS) || os(watchOS)
            displayLink?.invalidate()
            displayLink = nil
#else
            CVDisplayLinkStop(displayLink!)
#endif
        }
    }

    init(frameBuffer: UnsafePointer<UInt8>, refreshMode: DisplayRefreshMode) {
        self.refreshMode = refreshMode
        self.frameBuffer = frameBuffer
        self.bitmapContext = CGContext(
            data: drawingBuffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
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

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
