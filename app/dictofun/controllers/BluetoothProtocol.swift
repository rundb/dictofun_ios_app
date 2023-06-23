//
//  BluetoothProtocol.swift
//  dictofun
//
//  Created by Roman on 16.05.23.
//

import Foundation
import CoreBluetooth

/**
 This interface defines minimally sufficient functions for communication with a BLE device
 */
public protocol BleControlProtocol {
    func startScan()
    func stopScan()
    func connect()
    func disconnect()
    func registerService(serviceUUID: CBUUID)
    // TODO: fix this questionable return type
    func pair() -> Bool
    func unpair()
}

enum BleState {
    case idle
    case ready
    case scanning
    case connecting
    case connected
    case error
}

// This has to be a class, although it's mostly a POD structure. But in order to be correctly passed by reference
// into the classes, it has to be a class (structs are copied)
class BleContext {
    var bleState: BleState
    var isPaired: Bool
    var discoveredDevicesCount: Int
    
    init(bleState: BleState, isPaired: Bool)
    {
        self.bleState = bleState
        self.isPaired = isPaired
        self.discoveredDevicesCount = 0
    }
}
