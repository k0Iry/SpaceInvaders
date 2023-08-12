//
//  KeyInputControlView.swift
//  Invader
//
//  Created by xintu on 8/12/23.
//

import SwiftUI

struct KeyEvents: NSViewRepresentable {
    private let keyInputControlDelegate: KeyInputControlDelegate
    init(keyInputControlDelegate: KeyInputControlDelegate) {
        self.keyInputControlDelegate = keyInputControlDelegate
    }
    private class KeyView: NSView {
        var owner: KeyEvents?
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            if let action = Action(rawValue: event.keyCode) {
                owner?.keyInputControlDelegate.press(action)
            }
        }
        override func keyUp(with event: NSEvent) {
            if let action = Action(rawValue: event.keyCode) {
                owner?.keyInputControlDelegate.release(action)
            }
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
