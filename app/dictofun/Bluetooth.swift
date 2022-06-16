// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2022, Roman Turkin
 */

import CoreBluetooth

protocol BluetoothProtocol {
    func state(state: Bluetooth.State)
    func list(list: [Bluetooth.Device])
    func value(data: Data)
}

struct FtsContext {
    var filesCount: Int = 0
    var nextFileSize: Int = 0
    var receivedBytesCount: Int = 0
}

final class Bluetooth: NSObject {
    static let shared = Bluetooth()
    var delegate: BluetoothProtocol?
    
    var peripherals = [Device]()
    var current: CBPeripheral?
    var state: State = .unknown { didSet { delegate?.state(state: state) } }
    var userDefaults: UserDefaults = .standard
    var isPaired: Bool = false {didSet {delegate?.state(state: state)} }
    
    private var manager: CBCentralManager?
    private var pairingReadCharacteristic: CBCharacteristic?
    private var rxCharCharacteristic: CBCharacteristic?
    private var txCharCharacteristic: CBCharacteristic?
    private var fsInfoCharacteristic: CBCharacteristic?
    private var fileInfoCharacteristic: CBCharacteristic?
    
    private let rxCharCharacteristicCBUUIDString: String = "03000002-4202-A882-EC11-B10DA4AE3CEB"
    private let txCharCharacteristicCBUUIDString: String = "03000003-4202-A882-EC11-B10DA4AE3CEB"
    private let fileInfoCharacteristicCBUUIDString: String = "03000004-4202-A882-EC11-B10DA4AE3CEB"
    private let fsInfoCharacteristicCBUUIDString: String = "03000005-4202-A882-EC11-B10DA4AE3CEB"
    private let pairingReadCharacteristicCBUUIDString: String = "03000006-4202-A882-EC11-B10DA4AE3CEB"
    
    private var _context: FtsContext = FtsContext(filesCount: 0, nextFileSize: 0, receivedBytesCount: 0)
    
    let isPairedAlreadyKey: String = "isPaired"
    
    private override init() {
        super.init()
        manager = CBCentralManager(delegate: self, queue: .none)
        manager?.delegate = self
        
        let isPairedValue = userDefaults.value(forKey: "isPaired")
        if (isPairedValue != nil) == true
        {
            isPaired = true
        }
    }
    
    func connect(_ peripheral: CBPeripheral) {
        if current != nil {
            guard let current = current else { return }
            manager?.cancelPeripheralConnection(current)
            manager?.connect(peripheral, options: nil)
        } else { manager?.connect(peripheral, options: nil) }
    }
    
    func disconnect() {
        guard let current = current else { return }
        manager?.cancelPeripheralConnection(current)
    }
    
    func startScanning() {
        peripherals.removeAll()
        manager?.scanForPeripherals(withServices: nil, options: nil)
    }
    func stopScanning() {
        peripherals.removeAll()
        manager?.stopScan()
    }
    
    func pair() {
        guard let characteristic = pairingReadCharacteristic else { return }
        current?.readValue(for: characteristic)
    }
    
    func startDownload() {
        print("sending a download start request to the device")
        guard let characteristic = rxCharCharacteristic else { return }
        var request = 3
        let requestData = Data(bytes: &request,
                             count: MemoryLayout.size(ofValue: request))
        current?.writeValue(requestData, for: characteristic, type: .withoutResponse)
    }
    
    func requestNextFileSize() {
        print("requesting size of the next file")
        guard let characteristic = rxCharCharacteristic else { return }
        var request = 2
        let requestData = Data(bytes: &request,
                             count: MemoryLayout.size(ofValue: request))
        current?.writeValue(requestData, for: characteristic, type: .withoutResponse)
    }
    
    func requestNextFileData() {
        print("requesting next file data")
        guard let characteristic = rxCharCharacteristic else { return }
        var request = 1
        let requestData = Data(bytes: &request,
                             count: MemoryLayout.size(ofValue: request))
        current?.writeValue(requestData, for: characteristic, type: .withoutResponse)
    }
    
    enum State { case unknown, resetting, unsupported, unauthorized, poweredOff, poweredOn, error, connected, disconnected }
    
    struct Device: Identifiable {
        let id: Int
        let rssi: Int
        let uuid: String
        let peripheral: CBPeripheral
    }
}

extension Bluetooth: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch manager?.state {
        case .unknown: state = .unknown
        case .resetting: state = .resetting
        case .unsupported: state = .unsupported
        case .unauthorized: state = .unauthorized
        case .poweredOff: state = .poweredOff
        case .poweredOn: state = .poweredOn
        default: state = .error
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let uuid = String(describing: peripheral.identifier)
        let filtered = peripherals.filter{$0.uuid == uuid}
        if filtered.count == 0{
            guard let name = peripheral.name else { return }
            let new = Device(id: peripherals.count, rssi: RSSI.intValue, uuid: uuid, peripheral: peripheral)
            peripherals.append(new)
            delegate?.list(list: peripherals)
            if isPaired && name.starts(with: "dictofun")
            {
                print("discovered paired dictofun, trying to connect")
                self.connect(new.peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?)
    {
        print("failed to connect")
        print(error!)
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        current = nil
        state = .disconnected
        print("disconnected peripheral")
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        current = peripheral
        state = .connected
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
}

extension Bluetooth: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        let pairingCharacteristicCBUUID = CBUUID(string: self.pairingReadCharacteristicCBUUIDString);
        let fsInfoCharacteristicCBUUID = CBUUID(string: self.fsInfoCharacteristicCBUUIDString);
        let fileInfoCharacteristicCBUUID = CBUUID(string: self.fileInfoCharacteristicCBUUIDString);
        let rxCharCharacteristicCBUUID = CBUUID(string: self.rxCharCharacteristicCBUUIDString);
        let txCharCharacteristicCBUUID = CBUUID(string: self.txCharCharacteristicCBUUIDString);
        for characteristic in characteristics {
            if characteristic.uuid.isEqual(pairingCharacteristicCBUUID)
            {
                pairingReadCharacteristic = characteristic
            }
            if characteristic.uuid.isEqual(fsInfoCharacteristicCBUUID)
            {
                fsInfoCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.uuid.isEqual(fileInfoCharacteristicCBUUID)
            {
                fileInfoCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if (characteristic.uuid.isEqual(rxCharCharacteristicCBUUID))
            {
                rxCharCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if (characteristic.uuid.isEqual(txCharCharacteristicCBUUID))
            {
                txCharCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        print("did write value for \(descriptor.uuid)")
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("did update notification state for \(characteristic)")
        
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        print("update value for a descriptor")
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let value = characteristic.value else { return }
        delegate?.value(data: value)
        if characteristic.uuid == CBUUID(string: pairingReadCharacteristicCBUUIDString)
        {
            isPaired = true
            userDefaults.set(true, forKey: isPairedAlreadyKey)
            print("pairing successfull")
        }
        if characteristic.uuid == CBUUID(string: fsInfoCharacteristicCBUUIDString)
        {
            let value = [UInt8](characteristic.value!)
            print("fs file count = \(_context.filesCount)")
            _context.filesCount = Int(value[0]) + 256 * Int(value[1]);
            requestNextFileSize()
        }
        if characteristic.uuid == CBUUID(string: fileInfoCharacteristicCBUUIDString)
        {
            let value = [UInt8](characteristic.value!)
            _context.nextFileSize =
                Int(value[1]) +
                256 * Int(value[2]) +
                256 * 256 * Int(value[3]) +
                256 * 256 * 256 * Int(value[4]);
            _context.receivedBytesCount = 0
            print("next file size = \(_context.nextFileSize)")
            requestNextFileData()
        }
        if characteristic.uuid == CBUUID(string: txCharCharacteristicCBUUIDString)
        {
            _context.receivedBytesCount += (characteristic.value?.count ?? 0)
            if _context.receivedBytesCount == _context.nextFileSize
            {
                print("file received, requesting next one(\(_context.nextFileSize)/\(_context.receivedBytesCount))")
                _context.filesCount -= 1
                requestNextFileSize()
            }
            
        }
    }
}
