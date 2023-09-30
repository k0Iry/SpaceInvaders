//
//  ControlPanel.swift
//  Invader-iOS
//
//  Created by xintu on 8/12/23.
//

import SwiftUI

struct ControlPanel: View {
    private let keyInputDelegate: KeyInputControlDelegate?
    
    @State private var startButtonTitle = "▶"
    
    init(keyInputDelegate: KeyInputControlDelegate?) {
        self.keyInputDelegate = keyInputDelegate
    }
    
    var body: some View {
        HStack {
            VStack {
                HStack {
                    Button(startButtonTitle) {
                        keyInputDelegate?.press(.pause)
                        startButtonTitle = startButtonTitle == "▶" ? "▶॥" : "▶"
                    }
                    Button("↻") {
                        keyInputDelegate?.press(.restart)
                    }
                }.padding()
            }
            VStack {
                HStack {
                    Button("💰", action: {}).onLongPressGesture(perform: {}) { pressing in
                        if pressing {
                            keyInputDelegate?.press(.coin)
                        } else {
                            keyInputDelegate?.release(.coin)
                        }
                    }
                    Button("👾", action: {}).onLongPressGesture(perform: {}) { pressing in
                        if pressing {
                            keyInputDelegate?.press(.start)
                        } else {
                            keyInputDelegate?.release(.start)
                        }
                    }
                }.padding()
            }
        }.padding().buttonStyle(.bordered).buttonBorderShape(.circle)
    }
}

