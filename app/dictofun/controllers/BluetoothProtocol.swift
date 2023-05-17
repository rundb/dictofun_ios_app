//
//  BluetoothProtocol.swift
//  dictofun
//
//  Created by Roman on 16.05.23.
//

import Foundation

public protocol BleControlProtocol {
    func startScan()
    func connect()
    func disconnect()
}

enum BleState {
    case idle
    case scanning
    case connecting
    case connected
}

struct BleContext {
    var bleState: BleState
    var isPaired: Bool
}
