//
//  BleControllerMock.swift
//  dictofun
//
//  Created by Roman on 16.05.23.
//

import Foundation
import CoreBluetooth

class BleControllerMock: BleControlProtocol
{
    func startScan() {
        print("start scan called")
    }
    
    func stopScan() {
        print("stop scan called")
    }
    
    func connect() {
        print("connect called")
    }
    
    func disconnect() {
        print("disconnect called")
    }
    
    func registerService(serviceUUID: CBUUID) {
        
    }
    
}
