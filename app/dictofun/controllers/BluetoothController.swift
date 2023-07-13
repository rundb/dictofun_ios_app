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
    
    // Pairing stuff, hardcoded here
    private var pairingWriteCharacteristic: CBCharacteristic?
    private let pairingWriteCharacteristicCBUUIDString: String = "000010fe-0000-1000-8000-00805f9b34fb"
    
    struct Device: Identifiable {
        let id: Int
        let rssi: Int
        let uuid: String
        let peripheral: CBPeripheral
    }
    
    override init() {
        super.init()
        cbCentralManager = CBCentralManager(delegate: self, queue: .none) // TODO: figure out what queue could be used here and why?
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
    
    func pair() -> Bool {
        if bleContext?.bleState != .connected {
            return false
        }
        
        // it is hardcoded here, it's bad, so maybe a better way should be used for pairing
        if pairingWriteCharacteristic == nil {
            NSLog("no pairing characteristic found")
            return false
        }
        
        var request = 1
        let requestData = Data(bytes: &request, count: MemoryLayout.size(ofValue: request))
        currentPeripheral?.writeValue(requestData, for: pairingWriteCharacteristic!, type: .withResponse)
        
        // First write the pairing characteristic, then in case of success - update the context (TODO: move writing to the userDefaults into the delegate call)
        return true
    }
    
    func unpair() {
        userDefaults.setValue(false, forKey: self.isPairedKey)
        self.bleContext?.isPaired = false
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
    
    // At the moment works if and only if one single peripheral is discovered
    // Behavior in the case when multiple devices are found is TBD
    func connect() {
        NSLog("ble::connect is called")
        if peripherals.count != 1 {
            NSLog("ble::connect error - discovered devices' count != 1")
            return
        }
        if bleContext?.bleState == .connected {
            NSLog("ble::connect error - attempt to connect while another connection exists")
            return
        }
        let device = peripherals[0]
        cbCentralManager?.connect(device.peripheral, options: nil)
        bleContext?.bleState = .connecting
        NSLog("connect - entering state connecting")
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
            bleContext?.discoveredDevicesCount += 1
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        bleContext?.bleState = .connected
        // TODO: define further actions
        NSLog("centralManager: entering state connected")
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        currentPeripheral = peripheral
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        bleContext?.bleState = .ready // TBD, maybe it's scanning
        NSLog("centralManager: disconnected, entering state ready")
    }
}


// Peripheral delegate funcrtions
extension BluetoothController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            NSLog("discovered service id: %@", service.uuid.uuidString)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        NSLog("discovered characteristics")
        let pairingWriteCharacteristicCBUUID = CBUUID(string: pairingWriteCharacteristicCBUUIDString)
        for characteristic in characteristics {
            NSLog("discovered char id: %@", characteristic.uuid.uuidString)
            if characteristic.uuid.isEqual(pairingWriteCharacteristicCBUUID)
            {
                pairingWriteCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: pairingWriteCharacteristic!)
                NSLog("found pairing characteristic")
            }
        }
    }
        
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        NSLog("did write descr value for \(characteristic.uuid)")
        let pairingWriteCharacteristicCBUUID = CBUUID(string: pairingWriteCharacteristicCBUUIDString)
        if descriptor.uuid.isEqual(pairingWriteCharacteristicCBUUID)
        {
            NSLog("pairing has been completed")
            userDefaults.setValue(true, forKey: self.isPairedKey)
            self.bleContext?.isPaired = true
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        NSLog("char \(characteristic.uuid) has updated value")
    }
}
