// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2022, Roman Turkin
 */

import CoreBluetooth
import Foundation
import AVFoundation

protocol BluetoothProtocol {
    func state(state: Bluetooth.State)
    func list(list: [Bluetooth.Device])
    func value(data: Data)
}

enum FtsState {
    case disconnected, expect_fs_info, expect_file_info, data_transmission
}

struct FtsContext {
    var filesCount: Int = 0
    var nextFileSize: Int = 0
    var receivedBytesCount: Int = 0
    var currentFileURL: URL?
    var state: FtsState
}


final class Bluetooth: NSObject {
    static let shared = Bluetooth()
    var delegate: BluetoothProtocol?
    
    var peripherals = [Device]()
    var current: CBPeripheral?
    var state: State = .unknown { didSet { delegate?.state(state: state) } }
    var userDefaults: UserDefaults = .standard
    var isPaired: Bool = false {didSet {delegate?.state(state: state)} }
    
    var recordsManager: RecordsManager?
    
    private var manager: CBCentralManager?
    private var pairingReadCharacteristic: CBCharacteristic?
    private var rxCharCharacteristic: CBCharacteristic?
    private var txCharCharacteristic: CBCharacteristic?
    private var fsInfoCharacteristic: CBCharacteristic?
    private var fileInfoCharacteristic: CBCharacteristic?
    
    private let ftsServiceCBUUIDString: String = "03000001-4202-A882-EC11-B10DA4AE3CEB"
    //private let dictofunUUID: String = "9015D4D5-9B84-AE95-AF5E-4A3186C2CF7A"
    
    private let rxCharCharacteristicCBUUIDString: String = "03000002-4202-A882-EC11-B10DA4AE3CEB"
    private let txCharCharacteristicCBUUIDString: String = "03000003-4202-A882-EC11-B10DA4AE3CEB"
    private let fileInfoCharacteristicCBUUIDString: String = "03000004-4202-A882-EC11-B10DA4AE3CEB"
    private let fsInfoCharacteristicCBUUIDString: String = "03000005-4202-A882-EC11-B10DA4AE3CEB"
    private let pairingReadCharacteristicCBUUIDString: String = "03000006-4202-A882-EC11-B10DA4AE3CEB"

    
    private var _context: FtsContext = FtsContext(filesCount: 0, nextFileSize: 0, receivedBytesCount: 0, currentFileURL: nil, state: .disconnected)
    let isPairedAlreadyKey: String = "isPaired"
    
    private override init() {
        super.init()
        manager = CBCentralManager(delegate: self, queue: .none)
        manager?.delegate = self
        recordsManager = RecordsManager.shared
        
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
        if _context.state != .disconnected
        {
            NSLog("startScanning(): wrong state. No action taken")
            return
        }
        peripherals.removeAll()
        let ftsServiceCBUUID = CBUUID(string: ftsServiceCBUUIDString)
        manager?.scanForPeripherals(withServices: [ftsServiceCBUUID])
    }
    func stopScanning() {
        peripherals.removeAll()
        manager?.stopScan()
        _context.state = .disconnected
    }
    
    func pair() {
        guard let characteristic = pairingReadCharacteristic else { return }
        current?.readValue(for: characteristic)
    }
    
    func startDownload() {
        if _context.state != .disconnected
        {
            //NSLog("startDownload(): wrong state. No action taken")
            return
        }
        else
        {
            NSLog("startDownload(): starting")
        }
        guard let characteristic = rxCharCharacteristic else
        {
            NSLog("rxChar assignment error (startDownload)")
            return
        }
        var request = 3
        let requestData = Data(bytes: &request,
                             count: MemoryLayout.size(ofValue: request))
        current?.writeValue(requestData, for: characteristic, type: .withResponse)
        _context.state = .expect_fs_info
    }
    
    func requestNextFileSize() {
        NSLog("requesting next file size")
        if _context.state != .expect_fs_info && _context.state != .data_transmission
        {
            NSLog("requestNextFileSize(): wrong state. No action taken")
            return
        }
        guard let characteristic = rxCharCharacteristic else
        {
            NSLog("rxChar assignment error (requestNextFileSize)")
            return
        }
        var request = 2
        let requestData = Data(bytes: &request,
                             count: MemoryLayout.size(ofValue: request))
        current?.writeValue(requestData, for: characteristic, type: .withResponse)
        _context.state = .expect_file_info
    }
    
    func requestNextFileData() {
        NSLog("requesting next file data")
        if _context.state != .expect_file_info
        {
            NSLog("requestNextFileData(): wrong state. No action taken")
            return
        }
        guard let characteristic = rxCharCharacteristic else
        {
            NSLog("rxCharChar assignment error (requestNextFileData)")
            return
        }
        var request = 1
        let requestData = Data(bytes: &request,
                             count: MemoryLayout.size(ofValue: request))
        current?.writeValue(requestData, for: characteristic, type: .withResponse)
        _context.state = .data_transmission
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
        case .poweredOn: do {
            self.state = .poweredOn
            startScanning()
        }
        default: state = .error
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let uuid = String(describing: peripheral.identifier)
        //let tmp_name = peripheral.name
        let filtered = peripherals.filter{$0.uuid == uuid}
        if filtered.count == 0{
            guard let name = peripheral.name else { return }
            let new = Device(id: peripherals.count, rssi: RSSI.intValue, uuid: uuid, peripheral: peripheral)
            peripherals.append(new)
            delegate?.list(list: peripherals)
            if isPaired && name.starts(with: "dictofun") && state != .connected
            {
                NSLog("discovered paired dictofun, trying to connect")
                self.connect(new.peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?)
    {
        NSLog("failed to connect, error=\(error!.localizedDescription)")
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        current = nil
        state = .disconnected
        _context.state = .disconnected
        startScanning()
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        current = peripheral
        state = .connected
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
}

extension Data {
    func append(fileURL: URL) throws {
        if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        }
        else {
            try write(to: fileURL, options: .atomic)
        }
    }
}

extension Bluetooth: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            NSLog("discovered service id: %@", service.uuid.uuidString)
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
        if isPaired && rxCharCharacteristic != nil && fileInfoCharacteristic != nil {
            usleep(100000)
            startDownload()
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        NSLog("did write value for \(descriptor.uuid)")
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        //NSLog("did update notification state for \(characteristic.uuid )")
        
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        NSLog("update value for a descriptor \(descriptor.uuid)")
    }
    
    /**
         This function implements file transmission state machine for the dictofun.
     BLE Central should implement following behavior:
     - write value 0x03 to rx char (see \startDownload). This triggers a request on the file system information
     - in the given callback on value update notification Central reads out the count of files. If files count == 0, end the state machine.
     - if files count > 0, request next available file size by writing value 0x02 to rx char (see requestNextFileSize())
     - in the given callback on value update notification Central receives the size of the next file that will be received
     - request next file data by writing value 0x01 to rx char (see requestNextFileData())
     - in the given callback on value update notification Central receives all of the files contents and stores the received data
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let value = characteristic.value else { return }
        delegate?.value(data: value)
        if characteristic.uuid == CBUUID(string: pairingReadCharacteristicCBUUIDString)
        {
            isPaired = true
            userDefaults.set(true, forKey: isPairedAlreadyKey)
            NSLog("pairing successfull")
        }
        else if characteristic.uuid == CBUUID(string: fsInfoCharacteristicCBUUIDString)
        {
            let value = [UInt8](characteristic.value!)
            _context.filesCount = Int(value[1]) + 256 * Int(value[2]);
            NSLog("fs file count = \(_context.filesCount)")
            requestNextFileSize()
        }
        else if characteristic.uuid == CBUUID(string: fileInfoCharacteristicCBUUIDString)
        {
            let value = [UInt8](characteristic.value!)
            _context.nextFileSize =
                Int(value[1]) +
                256 * Int(value[2]) +
                256 * 256 * Int(value[3]) +
                256 * 256 * 256 * Int(value[4]);
            _context.receivedBytesCount = 0
            NSLog("next file size = \(_context.nextFileSize)")
            requestNextFileData()
            _context.currentFileURL = recordsManager!.openRecordFile()
        }
        else if characteristic.uuid == CBUUID(string: txCharCharacteristicCBUUIDString)
        {
            _context.receivedBytesCount += (characteristic.value?.count ?? 0)
            do
            {
                try characteristic.value!.append(fileURL: _context.currentFileURL!)
            } catch {
                debugPrint("storage error \(error)")
            }
            
            if _context.receivedBytesCount == _context.nextFileSize
            {
                NSLog("file received, requesting next one(\(_context.nextFileSize)/\(_context.receivedBytesCount))")
                _context.filesCount -= 1
                do {
                    var data: Data?
                    try data = Data(contentsOf: _context.currentFileURL!)
                    
                    NSLog("Received file size: \(data?.count ?? 0)")
                }
                catch {
                    debugPrint("failed to open the file that just has been recorded")
                    return
                }
                recordsManager?.finalizeRecord(recordURL: _context.currentFileURL!)
                
                requestNextFileSize()
            }
        }
        else
        {
            NSLog("file reception: unknown condition")
        }
    }
}
