//
//  BleControllerMock.swift
//  dictofun
//
//  Created by Roman on 16.05.23.
//

import Foundation

class BleControllerMock: BleControlProtocol
{
//    var context: BleContext
    
//    init(context: BleContext)
//    {
//        self.context = context
//    }
    
    func startScan() {
        print("start scan called")
    }
    
    func connect() {
        print("connect called")
    }
    
    func disconnect() {
        print("disconnect called")
    }
    
    
}
