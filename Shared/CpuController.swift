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

    var videoFramePipeline: VideoFramePipeline

    init(refreshMode: DisplayRefreshMode = .original60) {
        guard let romURL = Bundle.main.url(forResource: "invaders", withExtension: nil),
              let romData = try? Data(contentsOf: romURL)
        else {
            fatalError("Failed to load invaders ROM from app bundle")
        }

        self.machine = I8080Machine(romData: romData)
        self.videoFramePipeline = VideoFramePipeline(videoRAM: machine.videoRAM, refreshMode: refreshMode)
        
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

            switch machine.runVBlankSlice(io: ioObject) {
            case .running:
                break
            case .halted:
                stateLock.withLock {
                    isRunning = false
                }
                videoFramePipeline.setDisplayUpdatesEnabled(false)
            case .fault(let status):
                assertionFailure("CPU slice failed with status \(status.rawValue)")
                stateLock.withLock {
                    isRunning = false
                }
                videoFramePipeline.setDisplayUpdatesEnabled(false)
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
            videoFramePipeline.setDisplayUpdatesEnabled(nowRunning)
        default:
            ioObject.perform(action)
        }
    }

    func release(_ action: Action) {
        ioObject.withdraw(action)
    }
}

final internal class VideoFramePipeline {
    private static let bytesPerColumn = height / 8
    private static let packedFrameBufferSize = width * bytesPerColumn
    
#if os(iOS) || os(tvOS) || os(watchOS)
    private var displayLink: CADisplayLink?
#else
    private var displayLink: CVDisplayLink?
#endif

    private let packedFrameSnapshot = UnsafeMutablePointer<UInt8>.allocate(capacity: width * (height / 8))
    private let videoRAM: UnsafePointer<UInt8>
    private let refreshMode: DisplayRefreshMode
    private let renderQueue = DispatchQueue(label: "SpaceInvaders.VideoFramePipeline", qos: .userInteractive)
    private let renderStateLock = NSLock()
    private let frameSnapshotLock = NSLock()

    private var hasFrameSnapshot = false
    private var renderInFlight = false
    private var publishedFrameRevision: UInt64 = 0

#if os(macOS)
    private func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        CVDisplayLinkSetOutputHandler(displayLink!) { (_, _, _, _, _) in
            self.scheduleFrameSnapshot()
            return kCVReturnSuccess
        }
    }
#endif

    internal func setDisplayUpdatesEnabled(_ enable: Bool) {
        if enable {
#if os(iOS) || os(tvOS) || os(watchOS)
            guard displayLink == nil else { return }
            let displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
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
            renderStateLock.withLock {
                renderInFlight = false
            }
        }
    }

    init(videoRAM: UnsafePointer<UInt8>, refreshMode: DisplayRefreshMode) {
        self.refreshMode = refreshMode
        self.videoRAM = videoRAM
        self.packedFrameSnapshot.initialize(repeating: 0, count: Self.packedFrameBufferSize)
#if os(macOS)
        setupDisplayLink()
#endif
    }

    deinit {
        packedFrameSnapshot.deinitialize(count: Self.packedFrameBufferSize)
        packedFrameSnapshot.deallocate()
    }

    internal func withLatestPackedFrameIfNeeded<T>(
        after revision: UInt64,
        _ body: (UnsafePointer<UInt8>, UInt64) -> T
    ) -> T? {
        frameSnapshotLock.withLock {
            guard publishedFrameRevision != revision else { return nil }
            return body(UnsafePointer(packedFrameSnapshot), publishedFrameRevision)
        }
    }

#if os(iOS) || os(tvOS) || os(watchOS)
    @objc private func displayLinkFired() {
        scheduleFrameSnapshot()
    }
#endif

    private func scheduleFrameSnapshot() {
        let shouldSchedule = renderStateLock.withLock { () -> Bool in
            guard !renderInFlight else { return false }
            renderInFlight = true
            return true
        }

        guard shouldSchedule else { return }

        renderQueue.async { [weak self] in
            self?.captureLatestFrameSnapshot()
        }
    }

    private func captureLatestFrameSnapshot() {
        defer {
            renderStateLock.withLock {
                renderInFlight = false
            }
        }

        let didChange = frameSnapshotLock.withLock { () -> Bool in
            var didChange = !hasFrameSnapshot

            for packedIndex in 0..<Self.packedFrameBufferSize {
                let pixel = videoRAM[packedIndex]
                if hasFrameSnapshot, pixel == packedFrameSnapshot[packedIndex] {
                    continue
                }

                packedFrameSnapshot[packedIndex] = pixel
                didChange = true
            }

            if didChange {
                hasFrameSnapshot = true
                publishedFrameRevision &+= 1
            }

            return didChange
        }

        guard didChange else { return }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
