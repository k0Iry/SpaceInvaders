//
//  ContentView.swift
//  Invader
//
//  Created by xintu on 6/19/23.
//

import SwiftUI
import QuartzCore
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

let width = 224
let height = 256

struct InvadersView: View {
    @Binding public private(set) var bitmapImage: CGImage?
    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    var body: some View {
        VStack {
            PlatformInvadersView(bitmapImage: bitmapImage, inverted: colorScheme != .dark)
                .aspectRatio(CGSize(width: CGFloat(width), height: CGFloat(height)), contentMode: .fit)
        }
#if os(iOS) || os(tvOS) || os(watchOS)
        .frame(maxHeight: .infinity, alignment: .top)
#endif
    }
}

#if os(iOS) || os(tvOS)
private struct PlatformInvadersView: UIViewRepresentable {
    let bitmapImage: CGImage?
    let inverted: Bool

    func makeUIView(context: Context) -> InvadersLayerView {
        InvadersLayerView()
    }

    func updateUIView(_ uiView: InvadersLayerView, context: Context) {
        uiView.setImage(bitmapImage, inverted: inverted)
    }
}

private final class InvadersLayerView: UIView {
    override class var layerClass: AnyClass { CALayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
        backgroundColor = .black
        contentMode = .scaleAspectFit
        configureLayer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureLayer() {
        let layer = self.layer
        layer.contentsGravity = .resizeAspect
        layer.magnificationFilter = .nearest
        layer.minificationFilter = .nearest
        layer.contentsScale = UIScreen.main.scale
    }

    func setImage(_ image: CGImage?, inverted: Bool) {
        layer.contents = image
        if inverted {
            layer.compositingFilter = "CIColorInvert"
            backgroundColor = .white
        } else {
            layer.compositingFilter = nil
            backgroundColor = .black
        }
    }
}
#elseif os(macOS)
private struct PlatformInvadersView: NSViewRepresentable {
    let bitmapImage: CGImage?
    let inverted: Bool

    func makeNSView(context: Context) -> InvadersLayerView {
        InvadersLayerView()
    }

    func updateNSView(_ nsView: InvadersLayerView, context: Context) {
        nsView.setImage(bitmapImage, inverted: inverted)
    }
}

private final class InvadersLayerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        layer?.contentsGravity = .resizeAspect
        layer?.magnificationFilter = .nearest
        layer?.minificationFilter = .nearest
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(_ image: CGImage?, inverted: Bool) {
        layer?.contents = image
        if inverted {
            layer?.compositingFilter = "CIColorInvert"
            layer?.backgroundColor = NSColor.white.cgColor
        } else {
            layer?.compositingFilter = nil
            layer?.backgroundColor = NSColor.black.cgColor
        }
    }
}
#endif
