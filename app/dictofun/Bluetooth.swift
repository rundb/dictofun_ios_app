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

final class Bluetooth: NSObject {
    static let shared = Bluetooth()
    var delegate: BluetoothProtocol?
    
    var peripherals = [Device]()
    var current: CBPeripheral?
    var state: State = .unknown { didSet { delegate?.state(state: state) } }
    var isPaired: Bool = false {didSet {delegate?.state(state: state)} }
    
    private var manager: CBCentralManager?
    private var pairingReadCharacteristic: CBCharacteristic?
    private var fsInfoCharacteristic: CBCharacteristic?
    private var fileInfoCharacteristic: CBCharacteristic?
    
    private let pairingReadCharacteristicCBUUIDString: String = "03000006-4202-A882-EC11-B10DA4AE3CEB"
    private let fsInfoCharacteristicCBUUIDString: String = "03000005-4202-A882-EC11-B10DA4AE3CEB"
    private let fileInfoCharacteristicCBUUIDString: String = "03000004-4202-A882-EC11-B10DA4AE3CEB"
    
    private override init() {
        super.init()
        manager = CBCentralManager(delegate: self, queue: .none)
        manager?.delegate = self
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
    
    func send(_ value: [UInt8]) {
//        guard let characteristic = writeCharacteristic else { return }
//        current?.writeValue(Data(value), for: characteristic, type: .withResponse)
    }
    
    func read() {
//        guard let characteristic = notifyCharacteristic else { return }
//        current?.readValue(for: characteristic)
//        var value = [UInt8] ()
//        value.append(0)
//        current?.writeValue(Data(value), for: characteristic, type: .withResponse)
    }
    func pair() {
        guard let characteristic = pairingReadCharacteristic else { return }
        current?.readValue(for: characteristic)
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
            guard let _ = peripheral.name else { return }
            let new = Device(id: peripherals.count, rssi: RSSI.intValue, uuid: uuid, peripheral: peripheral)
            peripherals.append(new)
            delegate?.list(list: peripherals)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) { print(error!) }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        current = nil
        state = .disconnected
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
        for characteristic in characteristics {
            print(characteristic.uuid)
            if characteristic.uuid.isEqual(pairingCharacteristicCBUUID)
            {
                pairingReadCharacteristic = characteristic
            }
            if characteristic.uuid.isEqual(fsInfoCharacteristicCBUUID)
            {
                fsInfoCharacteristic = characteristic
            }
            if characteristic.uuid.isEqual(fileInfoCharacteristicCBUUID)
            {
                fileInfoCharacteristic = characteristic
            }
            switch characteristic.properties {
            case .read:
                print("read ")
            case.broadcast:
                print("broadcast")
            case.writeWithoutResponse:
                print("writeWithoutResponse")
            case.indicate:
                print("indicate")
            case.extendedProperties:
                print("extendedProperties")
            case .write:
                print("write ")
            case .notify:
                peripheral.setNotifyValue(true, for: characteristic)
                print("notify")
            default:
                print("other property")
            }
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) { }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) { }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let value = characteristic.value else { return }
        print("didUpdateValueFor")
        print(characteristic)
        delegate?.value(data: value)
        if characteristic.uuid == CBUUID(string: pairingReadCharacteristicCBUUIDString)
        {
            isPaired = true
            print("pairing successfull")
        }
    }
}
