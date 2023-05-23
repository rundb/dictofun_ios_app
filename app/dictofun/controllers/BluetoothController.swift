//
//  BluetoothController.swift
//  dictofun
//
//  Created by Roman on 23.05.23.
//

import Foundation
import CoreBluetooth

/**
 This class implements BleControllerProtocol. Goal is to be able to run BLE applications on the phone, and still be able to run UI tests in the simulator.
 Therefore, this class should decouple details of CoreBluetooth usage from the interface.
 */
final class BluetoothController: NSObject {
    private var cbCentralManager: CBCentralManager?
    private var userDefaults: UserDefaults = .standard
    
    private let isPairedKey: String = "isPaired"
    
    private var bleContext: BleContext
    private var serviceUUIDs: [CBUUID]
    
    private var peripherals = [Device]()
    private var currentPeripheral: CBPeripheral?
    
    struct Device: Identifiable {
        let id: Int
        let rssi: Int
        let uuid: String
        let peripheral: CBPeripheral
    }
    
    // NB: probably services could also be taken into the context, but this way dependency to CoreBluetooth is
    //     pulled into hardware-agnostic part of the app.
    init(bleContext: BleContext, serviceUUIDs: [CBUUID]) {
        self.bleContext = bleContext
        self.serviceUUIDs = serviceUUIDs
        super.init()
        cbCentralManager = CBCentralManager(delegate: self, queue: .none) // TODO: figure out what queue could be used here and why?
        //cbCentralManager?.delegate = self // is this line needed? doesn't seem so
        let isPairedValue = userDefaults.value(forKey: self.isPairedKey)
        if (isPairedValue != nil) == true
        {
            self.bleContext.isPaired = true
        }
    }
}

extension BluetoothController: BleControlProtocol {
    func startScan() {
        if self.bleContext.bleState != .idle
        {
            NSLog("ble::startScan(): wrong state, scanning won't be started")
            return
        }
        peripherals.removeAll()
        cbCentralManager?.scanForPeripherals(withServices: serviceUUIDs)
        self.bleContext.bleState = .scanning
    }
    
    func stopScan() {
        cbCentralManager?.stopScan()
        peripherals.removeAll()
        self.bleContext.bleState = .idle
    }
    
    func connect() {
        NSLog("ble::connect is called")
    }
    
    func disconnect() {
        NSLog("ble::disconnect is called")
    }
    
    
}

extension BluetoothController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("centralManagerDidUpdateState")
    }
    
}
