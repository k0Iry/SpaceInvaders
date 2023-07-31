//
//  ContentView.swift
//  Invader
//
//  Created by xintu on 6/19/23.
//

import SwiftUI

let width = 224
let height = 256

#if os(macOS)
private struct KeyEvents: NSViewRepresentable {
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
#endif

struct ContentView: View {
    
    @StateObject private var cpuController = CpuController()
    
    var body: some View {
        VStack {
            if let image = cpuController.bitmapImage {
                Image(image, scale: 1.0, label: Text("Invaders"))
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(CGSize(width: CGFloat(width), height: CGFloat(height)), contentMode: .fit)
            }
#if os(iOS) || os(tvOS) || os(watchOS)
            HStack {
                Button(cpuController.title, action: {
                    cpuController.press(.pause)
                })
                Button("Drop Coins", action: {}).onLongPressGesture(perform: {}, onPressingChanged: { pressing in
                    if pressing {
                        cpuController.press(.coin)
                    } else {
                        cpuController.release(.coin)
                    }
                })
                Button("New Game", action: {}).onLongPressGesture(perform: {}, onPressingChanged: { pressing in
                    if pressing {
                        cpuController.press(.start)
                    } else {
                        cpuController.release(.start)
                    }
                })
            }.padding().buttonStyle(.borderedProminent)
            HStack {
                Button("<", action: {}).onLongPressGesture(perform: {}, onPressingChanged: { pressing in
                    if pressing {
                        cpuController.press(.left)
                    } else {
                        cpuController.release(.left)
                    }
                })
                Button("fire🔥", action: {}).onLongPressGesture(perform: {}, onPressingChanged: { pressing in
                    if pressing {
                        cpuController.press(.fire)
                    } else {
                        cpuController.release(.fire)
                    }
                })
                Button(">", action: {}).onLongPressGesture(perform: {}, onPressingChanged: { pressing in
                    if pressing {
                        cpuController.press(.right)
                    } else {
                        cpuController.release(.right)
                    }
                })
            }.padding().buttonStyle(.borderedProminent)
            Button("Restart", action: {
                cpuController.press(.restart)
            }).buttonStyle(.borderedProminent)
#endif
        }.padding()
#if os(macOS)
            .background(KeyEvents(keyInputControlDelegate: cpuController))
#endif
    }
}



