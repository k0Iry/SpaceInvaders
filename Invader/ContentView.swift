//
//  ContentView.swift
//  Invader
//
//  Created by xintu on 6/19/23.
//

import SwiftUI

private struct KeyEvents: NSViewRepresentable {
    private let keyInputControlDelegate: KeyInputControlDelegate
    init(keyInputControlDelegate: KeyInputControlDelegate) {
        self.keyInputControlDelegate = keyInputControlDelegate
    }
    private class KeyView: NSView {
        var owner: KeyEvents?
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            owner?.keyInputControlDelegate.keyDown(with: event.keyCode)
        }
        override func keyUp(with event: NSEvent) {
            owner?.keyInputControlDelegate.keyUp(with: event.keyCode)
        }
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.owner = self
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ContentView: View {
    
    @StateObject private var cpuController = CpuController().start()
    
    var body: some View {
        VStack {
            if let image = cpuController.bitmapImage {
                Image(image, scale: 1.0, label: Text("Invaders"))
                    .resizable()
                    .interpolation(.none)
                    .frame(width: cpuController.imageSize.width, height: cpuController.imageSize.height)
            }
        }
        .background(KeyEvents(keyInputControlDelegate: cpuController))
    }
}



