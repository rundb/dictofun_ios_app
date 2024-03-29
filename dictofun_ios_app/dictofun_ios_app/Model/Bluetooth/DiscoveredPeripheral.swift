// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import CoreBluetooth

class DiscoveredPeripheral: Equatable {
    
    let peripheral: CBPeripheral
    var rssi: Int32
    
    init(with peripheral: CBPeripheral, RSSI rssi:Int32 = 0) {
        self.peripheral = peripheral
        self.rssi = rssi
    }

    var name: String { peripheral.name ?? "No name" }
    var isConnected: Bool { peripheral.state == .connected }
}

func ==(lhs: DiscoveredPeripheral, rhs: DiscoveredPeripheral) -> Bool {
    lhs.peripheral == rhs.peripheral
        && lhs.isConnected == rhs.isConnected
        && lhs.rssi == rhs.rssi
}
