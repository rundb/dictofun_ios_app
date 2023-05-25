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
    
    private var bleContext: BleContext?
    private var serviceUUIDs = [CBUUID] ()
    
    private var peripherals = [Device]()
    private var currentPeripheral: CBPeripheral?
    
    struct Device: Identifiable {
        let id: Int
        let rssi: Int
        let uuid: String
        let peripheral: CBPeripheral
    }
    
    override init() {
        super.init()
        cbCentralManager = CBCentralManager(delegate: self, queue: .none) // TODO: figure out what queue could be used here and why?
        //cbCentralManager?.delegate = self // is this line needed? doesn't seem so
    }
    
    func registerBleContext(bleContext: inout BleContext)
    {
        self.bleContext = bleContext
        let isPairedValue = userDefaults.value(forKey: self.isPairedKey)
        if (isPairedValue != nil) == true
        {
            self.bleContext!.isPaired = true
        }
    }
    
    
    func registerService(serviceUUID: CBUUID) {
        self.serviceUUIDs.append(serviceUUID)
    }
}

extension BluetoothController: BleControlProtocol {
    func startScan() {
        if self.bleContext!.bleState != .ready
        {
            NSLog("ble::startScan(): wrong state, scanning won't be started")
            return
        }
        peripherals.removeAll()
        cbCentralManager?.scanForPeripherals(withServices: serviceUUIDs)
        self.bleContext!.bleState = .scanning
        
        NSLog("start scan: new BLE state = " + BluetoothController.bleStateToString(bleContext!.bleState))
    }
    
    func stopScan() {
        cbCentralManager?.stopScan()
        peripherals.removeAll()
        self.bleContext!.bleState = .ready
    }
    
    func connect() {
        NSLog("ble::connect is called")
    }
    
    func disconnect() {
        NSLog("ble::disconnect is called")
    }
    
    
}

extension BluetoothController: CBCentralManagerDelegate {
    static func cbManagerStateToString(_ state: CBManagerState) -> String
    {
        switch (state){
        case .unknown: return "unknown"
        case .resetting: return "resetting"
        case .unsupported: return "unsupported"
        case .unauthorized: return "unauthorized"
        case .poweredOff: return "poweredOff"
        case .poweredOn: return "poweredOn"
        default: return "other"
        }
    }
    
    static func bleStateToString(_ state: BleState) -> String {
        switch (state) {
            
        case .idle: return "idle"
        case .ready: return "ready"
        case .scanning: return "scanning"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .error: return "error"
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        NSLog("centralManagerDidUpdateState state update to " + BluetoothController.cbManagerStateToString(cbCentralManager!.state))
        switch cbCentralManager?.state {
        case .unknown: bleContext!.bleState = .error
        case .resetting: bleContext!.bleState = .error
        case .unsupported: bleContext!.bleState = .error
        case .unauthorized: bleContext!.bleState = .error
        case .poweredOff: bleContext!.bleState = .idle
        case .poweredOn: bleContext!.bleState = .ready
        default: bleContext!.bleState = .error
        }
        
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let uuid = String(describing: peripheral.identifier)
        let filtered = peripherals.filter{$0.uuid == uuid}
        if filtered.count == 0 {
            guard let name = peripheral.name else { return }
            let new = Device(id: peripherals.count, rssi: RSSI.intValue, uuid: uuid, peripheral: peripheral)
            peripherals.append(new)
//            cbCentralManager?.list(list: peripherals)
            print("discovered device " + uuid + " " + name)
        }
    }
    
}
