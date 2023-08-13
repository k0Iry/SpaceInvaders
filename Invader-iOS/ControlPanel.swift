//
//  ControlPanel.swift
//  Invader-iOS
//
//  Created by xintu on 8/12/23.
//

import SwiftUI

struct ControlPanel: View {
    private let keyInputDelegate: KeyInputControlDelegate?
    
    @State private var startButtonTitle = "Start"
    
    init(keyInputDelegate: KeyInputControlDelegate?) {
        self.keyInputDelegate = keyInputDelegate
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(startButtonTitle, action: {
                    keyInputDelegate?.press(.pause)
                    if startButtonTitle != "Pause" {
                        startButtonTitle = "Pause"
                    } else {
                        startButtonTitle = "Resume"
                    }
                })
                Button("Drop Coins", action: {}).onLongPressGesture(perform: {}, onPressingChanged: { pressing in
                    if pressing {
                        keyInputDelegate?.press(.coin)
                    } else {
                        keyInputDelegate?.release(.coin)
                    }
                })
                Button("New Game", action: {}).onLongPressGesture(perform: {}, onPressingChanged: { pressing in
                    if pressing {
                        keyInputDelegate?.press(.start)
                    } else {
                        keyInputDelegate?.release(.start)
                    }
                })
            }.padding().buttonStyle(.borderedProminent)
            HStack {
                Button("<", action: {}).onLongPressGesture(perform: {}, onPressingChanged: { pressing in
                    if pressing {
                        keyInputDelegate?.press(.left)
                    } else {
                        keyInputDelegate?.release(.left)
                    }
                })
                Button("fire🔥", action: {}).onLongPressGesture(perform: {}, onPressingChanged: { pressing in
                    if pressing {
                        keyInputDelegate?.press(.fire)
                    } else {
                        keyInputDelegate?.release(.fire)
                    }
                })
                Button(">", action: {}).onLongPressGesture(perform: {}, onPressingChanged: { pressing in
                    if pressing {
                        keyInputDelegate?.press(.right)
                    } else {
                        keyInputDelegate?.release(.right)
                    }
                })
            }.padding().buttonStyle(.borderedProminent)
            Button("Restart", action: {
                keyInputDelegate?.press(.restart)
            }).buttonStyle(.borderedProminent)
        }
    }
}

