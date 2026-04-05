//
//  KeyInputControlView.swift
//  Invader
//
//  Created by xintu on 8/12/23.
//

import SwiftUI

struct KeyEvents: NSViewRepresentable {
    private let keyInputControlDelegate: KeyInputControlDelegate?

    init(keyInputControlDelegate: KeyInputControlDelegate?) {
        self.keyInputControlDelegate = keyInputControlDelegate
    }

    private final class KeyView: NSView {
        var keyInputControlDelegate: KeyInputControlDelegate?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.window else { return }
                if window.firstResponder !== self {
                    window.makeFirstResponder(self)
                }
            }
        }

        override func keyDown(with event: NSEvent) {
            guard let action = Action(rawValue: event.keyCode) else {
                super.keyDown(with: event)
                return
            }

            if event.isARepeat && (action == .pause || action == .restart) {
                return
            }

            keyInputControlDelegate?.press(action)
        }

        override func keyUp(with event: NSEvent) {
            guard let action = Action(rawValue: event.keyCode) else {
                super.keyUp(with: event)
                return
            }

            keyInputControlDelegate?.release(action)
        }
    }

    func makeNSView(context: Context) -> NSView {
        let view = KeyView(frame: .zero)
        view.keyInputControlDelegate = keyInputControlDelegate
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let keyView = nsView as? KeyView else { return }
        keyView.keyInputControlDelegate = keyInputControlDelegate

        if let window = keyView.window, window.firstResponder !== keyView {
            DispatchQueue.main.async {
                window.makeFirstResponder(keyView)
            }
        }
    }
}
