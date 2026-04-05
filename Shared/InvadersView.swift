//
//  ContentView.swift
//  Invader
//
//  Created by xintu on 6/19/23.
//

import SwiftUI
import MetalKit
import CoreGraphics
#if os(macOS)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

let width = 224
let height = 256

struct InvadersView: View {
    let bitmapProducer: BitmapProducer
    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    var body: some View {
        VStack {
            PlatformInvadersView(bitmapProducer: bitmapProducer, inverted: colorScheme != .dark)
                .aspectRatio(CGSize(width: CGFloat(width), height: CGFloat(height)), contentMode: .fit)
        }
#if os(iOS) || os(tvOS) || os(watchOS)
        .frame(maxHeight: .infinity, alignment: .top)
#endif
    }
}

private final class MetalInvadersRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice

    private static let packedFrameBufferSize = width * (height / 8)
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let packedFrameBuffer: MTLBuffer
    private var bitmapProducer: BitmapProducer
    private var inverted: Bool
    private var lastFrameRevision: UInt64 = 0

    init?(bitmapProducer: BitmapProducer, inverted: Bool) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let library = try? device.makeDefaultLibrary(bundle: .main),
              let vertexFunction = library.makeFunction(name: "invadersVertex"),
              let fragmentFunction = library.makeFunction(name: "invadersFragment")
        else {
            return nil
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor),
              let packedFrameBuffer = device.makeBuffer(length: Self.packedFrameBufferSize, options: .storageModeShared)
        else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.pipelineState = pipelineState
        self.packedFrameBuffer = packedFrameBuffer
        self.bitmapProducer = bitmapProducer
        self.inverted = inverted
        super.init()

        packedFrameBuffer.contents().initializeMemory(as: UInt8.self, repeating: 0, count: Self.packedFrameBufferSize)
    }

    func updateConfiguration(bitmapProducer: BitmapProducer, inverted: Bool) {
        self.bitmapProducer = bitmapProducer
        self.inverted = inverted
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        if let revision = bitmapProducer.withLatestFrameIfNeeded(after: lastFrameRevision, { frameBytes, revision in
            packedFrameBuffer.contents().copyMemory(from: frameBytes, byteCount: Self.packedFrameBufferSize)
            return revision
        }) {
            lastFrameRevision = revision
        }

        guard view.drawableSize.width > 0,
              view.drawableSize.height > 0,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            return
        }

        var invertAmount: Float = inverted ? 1.0 : 0.0

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBuffer(packedFrameBuffer, offset: 0, index: 0)
        encoder.setFragmentBytes(&invertAmount, length: MemoryLayout<Float>.size, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

private final class InvadersMetalView: MTKView {
#if os(macOS)
    override var acceptsFirstResponder: Bool { false }

    override func layout() {
        super.layout()
        refreshDrawableSize()
    }
#elseif os(iOS) || os(tvOS)
    override func layoutSubviews() {
        super.layoutSubviews()
        refreshDrawableSize()
    }
#endif

    func refreshDrawableSize() {
        let scale: CGFloat
#if os(macOS)
        scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
#else
        scale = window?.screen.scale ?? UIScreen.main.scale
#endif
        let scaledSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let clampedWidth = min(max(1, Int(scaledSize.width.rounded(.down))), 4096)
        let clampedHeight = min(max(1, Int(scaledSize.height.rounded(.down))), 4096)
        drawableSize = CGSize(width: clampedWidth, height: clampedHeight)
    }
}

private func configureMetalView(_ view: InvadersMetalView, renderer: MetalInvadersRenderer) {
    view.device = renderer.device
    view.delegate = renderer
    view.isPaused = false
    view.enableSetNeedsDisplay = false
    view.autoResizeDrawable = false
    view.framebufferOnly = true
    view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    view.colorPixelFormat = .bgra8Unorm
    view.preferredFramesPerSecond = 60
#if os(iOS) || os(tvOS)
    view.contentMode = .scaleAspectFit
    view.layer.magnificationFilter = .nearest
    view.layer.minificationFilter = .nearest
#elseif os(macOS)
    view.layer?.magnificationFilter = .nearest
    view.layer?.minificationFilter = .nearest
#endif
    view.refreshDrawableSize()
}

#if os(iOS) || os(tvOS)
private struct PlatformInvadersView: UIViewRepresentable {
    let bitmapProducer: BitmapProducer
    let inverted: Bool

    func makeCoordinator() -> MetalInvadersRenderer {
        guard let renderer = MetalInvadersRenderer(bitmapProducer: bitmapProducer, inverted: inverted) else {
            fatalError("Metal is unavailable on this device")
        }
        return renderer
    }

    func makeUIView(context: Context) -> InvadersMetalView {
        let view = InvadersMetalView(frame: .zero, device: context.coordinator.device)
        configureMetalView(view, renderer: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: InvadersMetalView, context: Context) {
        context.coordinator.updateConfiguration(bitmapProducer: bitmapProducer, inverted: inverted)
    }
}
#elseif os(macOS)
private struct PlatformInvadersView: NSViewRepresentable {
    let bitmapProducer: BitmapProducer
    let inverted: Bool

    func makeCoordinator() -> MetalInvadersRenderer {
        guard let renderer = MetalInvadersRenderer(bitmapProducer: bitmapProducer, inverted: inverted) else {
            fatalError("Metal is unavailable on this device")
        }
        return renderer
    }

    func makeNSView(context: Context) -> InvadersMetalView {
        let view = InvadersMetalView(frame: .zero, device: context.coordinator.device)
        configureMetalView(view, renderer: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: InvadersMetalView, context: Context) {
        context.coordinator.updateConfiguration(bitmapProducer: bitmapProducer, inverted: inverted)
    }
}
#endif
