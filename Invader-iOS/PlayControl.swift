//
//  PlayControl.swift
//  SpaceInvaders-iOS
//
//  Created by Xin Tu on 30/09/2023.
//

import SwiftUI

struct PlayControl: View {
    private let keyInputDelegate: KeyInputControlDelegate?
    
    init(keyInputDelegate: KeyInputControlDelegate?) {
        self.keyInputDelegate = keyInputDelegate
    }
    
    var body: some View {
        HStack {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                HStack {
                    Spacer()
                    Text("<")
                    Spacer()
                }.contentShape(Rectangle()).frame(height: 100)
            }.onLongPressGesture(perform: {}) { pressing in
                if pressing {
                    keyInputDelegate?.press(.left)
                } else {
                    keyInputDelegate?.release(.left)
                }
            }
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }) {
                HStack {
                    Spacer()
                    Text("🔥")
                    Spacer()
                }.contentShape(Rectangle()).frame(height: 100)
            }.onLongPressGesture(perform: {}) { pressing in
                if pressing {
                    keyInputDelegate?.press(.fire)
                } else {
                    keyInputDelegate?.release(.fire)
                }
            }
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                HStack {
                    Spacer()
                    Text(">")
                    Spacer()
                }.contentShape(Rectangle()).frame(height: 100)
            }.onLongPressGesture(perform: {}) { pressing in
                if pressing {
                    keyInputDelegate?.press(.right)
                } else {
                    keyInputDelegate?.release(.right)
                }
            }
        }.padding().buttonStyle(.bordered)
    }
}
