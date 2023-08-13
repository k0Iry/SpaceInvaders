//
//  IOModelProtocol.swift
//  Invader
//
//  Created by xintu on 8/13/23.
//

import Foundation

protocol IoModelProtocol {
    func input(port: UInt8) -> UInt8
    func output(port: UInt8, value: UInt8)
}
