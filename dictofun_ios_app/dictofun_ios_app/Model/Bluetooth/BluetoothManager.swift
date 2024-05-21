/*
 * Copyright (c) 2020, Nordic Semiconductor
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this
 *    list of conditions and the following disclaimer in the documentation and/or
 *    other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may
 *    be used to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 * 2023: Modifications introduced by Roman Turkin
 */



import UIKit
import CoreBluetooth
import Logging

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}

protocol BluetoothManagerDelegate {
    func requestedConnect(peripheral: CBPeripheral)
    func didConnectPeripheral(deviceName aName : String?)
    func didDisconnectPeripheral()
    func peripheralReady()
    func peripheralNotSupported()
}

protocol BleServicesDiscoveryDelegate {
    func didDiscoverServices()
    func onDisconnect()
}

protocol BASBatteryLevelUpdated {
    func didUpdateBatteryLevel(with level: Int)
}

enum BluetoothManagerError: Error {
    case cannotFindPeripheral
    
    var localizedDescription: String {
        "Can not find peripheral"
    }
}

enum ConnectionState {
    case on, off
}
protocol UIBleStatusUpdateDelegate {
    func didConnectionStatusUpdate(newState state: ConnectionState)
}

class BluetoothManager: NSObject, CBPeripheralDelegate, CBCentralManagerDelegate {
    
    //MARK: - Delegate Properties
    var delegate: BluetoothManagerDelegate?
    var scannerDelegate: ScannerDelegate?
    var connectDelegate: ConnectDelegate?
    var pairDelegate: PairDelegate?
    var uiUpdateDelegate: UIBleStatusUpdateDelegate?
    var serviceDiscoveryDelegate: BleServicesDiscoveryDelegate?
    var batteryLevelUpdateDelegate: BASBatteryLevelUpdated?
    
    //MARK: - Class Properties
    fileprivate let FTSServiceUUID             : CBUUID
    fileprivate let BASServiceUUID             : CBUUID
    fileprivate let DFUServiceUUID             : CBUUID
    fileprivate var isBASServiceFound = false
    fileprivate var isDFUServiceFound = false
    
    fileprivate var centralManager              : CBCentralManager
    fileprivate var bluetoothPeripheral         : CBPeripheral?
    
    var userDefaults: UserDefaults = .standard
    
    var logger: Logger?
    
    // FTS Characteristics
    let ftsCharsIDs: Set = [
        ServiceIds.FTS.controlPointCh,
        ServiceIds.FTS.statusCh,
        ServiceIds.FTS.fsStatusCh,
        ServiceIds.FTS.fileDataCh,
        ServiceIds.FTS.fileInfoCh,
        ServiceIds.FTS.fileListCh,
        ServiceIds.FTS.fileListNextCh,
        ServiceIds.pairingWriteCh
    ]
    var ftsChars: [String:CBCharacteristic?] = [:]
    
    fileprivate var connected = false
    var paired = false
    private var connectingPeripheral: CBPeripheral!
    var isUnpairingRequested = false
    
    private var batteryLevel: Int = 0
    
    private var dfuControlCharacteristic: CBCharacteristic?
    // MARK: - public API intended for use by services
    var charNotifyDelegates: [CBUUID : CharNotificationDelegate] = [:]
    
    enum CharOpError: Error {
        case notFound
        case notImplemented
        case other
    }
    
    private func getCharByCBUUID(with cbuuid: CBUUID) -> CBCharacteristic? {
        if let c = ftsChars[cbuuid.uuidString] {
            return c
        }
        return nil
    }
    
    func writeTo(characteristic char: CBUUID, with data: Data) -> Error? {
        if let characteristic = getCharByCBUUID(with: char) {
            bluetoothPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
            return nil
        }
        return .some(CharOpError.notImplemented)
    }
    
    func readFrom(characteristic char: CBCharacteristic) {
        bluetoothPeripheral?.readValue(for: char)
    }
    
    func getBatteryLevel() -> Int {
        return batteryLevel
    }
    
    func updateBatteryLevel(with level: Int) {
        batteryLevel = level
        if batteryLevelUpdateDelegate != nil {
            batteryLevelUpdateDelegate!.didUpdateBatteryLevel(with: level)
        }
    }
    
    func setNotificationStateFor(characteristic char: CBUUID, toEnabled state: Bool) -> Error? {
        if let characteristic = getCharByCBUUID(with: char) {
            bluetoothPeripheral?.setNotifyValue(state, for: characteristic)
            return nil
        }
        
        return .some(CharOpError.notFound)
    }
    
    func registerNotificationDelegate(forCharacteristic char: CBUUID, delegate: CharNotificationDelegate?) -> Error? {
        charNotifyDelegates[char] = delegate
        return nil
    }
    
    //MARK: - BluetoothManager API
    
    required init(withManager aManager : CBCentralManager = CBCentralManager()) {
        centralManager = aManager
        FTSServiceUUID          = CBUUID(string: ServiceIds.FTS.service)
        BASServiceUUID = CBUUID(string: ServiceIds.BAS.service)
        DFUServiceUUID = CBUUID(string: ServiceIds.DFU.service)

        super.init()
        
        
        centralManager.delegate = self
        initUserDefaults()
    }
    
    func init_logger() {
        logger = Logger(label: "ble")
        logger?.logLevel = .debug
    }
    
    func initUserDefaults() {
        let isPairedValue = userDefaults.value(forKey: K.isPairedKey)
        if isPairedValue == nil {
            userDefaults.setValue(false, forKey: K.isPairedKey)
            paired = false
            logger?.info("User default value for paired not found, resetting")
        }
        else {
            paired = isPairedValue as! Bool
        }
    }
    
    func startScanning() {
        centralManager.scanForPeripherals(withServices: [FTSServiceUUID])
    }
    
    func stopScanning() {
        centralManager.stopScan()
    }
    /**
     * Connects to the given peripheral.
     *
     * - parameter aPeripheral: target peripheral to connect to
     */
    func connectPeripheral(peripheral aPeripheral : CBPeripheral) {
        delegate?.requestedConnect(peripheral: aPeripheral)
        bluetoothPeripheral = aPeripheral

        guard let p = centralManager.retrievePeripherals(withIdentifiers: [aPeripheral.identifier]).first else {
            centralManager.delegate?.centralManager?(centralManager, didFailToConnect: aPeripheral, error: BluetoothManagerError.cannotFindPeripheral)
            return
        }
        connectingPeripheral = p
        centralManager.connect(p, options: nil)
    }
    
    /**
     * Disconnects or cancels pending connection.
     * The delegate's didDisconnectPeripheral() method will be called when device got disconnected.
     */
    func cancelPeripheralConnection() {
        guard bluetoothPeripheral != nil else {
            return
        }

        centralManager.cancelPeripheralConnection(bluetoothPeripheral!)
        
        // In case the previous connection attempt failed before establishing a connection
        if !connected {
            bluetoothPeripheral = nil
            delegate?.didDisconnectPeripheral()
        }
    }
    
    /**
     * Returns true if the peripheral device is connected, false otherwise
     * - returns: true if device is connected
     */
    func isConnected() -> Bool {
        return connected
    }
    
    enum PairingError: Error {
        case disconnected, alreadyPaired, pairingCharNotFound
    }
    
    func pairWithPeripheral(_ peripheral: CBPeripheral) -> Error? {
        // 1. attempt to write a value into pairing characteristic (it is encrypted and required pairing to have been performed)
        if !connected {
            return .some(PairingError.disconnected)
        }
        if paired {
            return .some(PairingError.alreadyPaired)
        }
        
        if let characteristic = ftsChars[ServiceIds.pairingWriteCh] {
            var request = 1
            let requestData = Data(bytes: &request, count: 1)
            
            peripheral.setNotifyValue(true, for: characteristic!)
            peripheral.writeValue(requestData, for: characteristic!, type: .withResponse)
            return nil
        }
        // 2. Rest of pairing functionality resides in pairingCallback
        // This point is unreachable, unless there was an error above
        return .some(PairingError.pairingCharNotFound)
    }
    
    func pairingCallback(error: Error?) {
        if !isUnpairingRequested {
            guard error == nil else {
                logger?.error("Pairing has failed. Aborting. Error: \(error!.localizedDescription)")
                pairDelegate?.didPairWithPeripheral(error: error)
                return
            }
            
            paired = true
            userDefaults.setValue(paired, forKey: K.isPairedKey)
            pairDelegate?.didPairWithPeripheral(error: nil)
        }
        else {
            if error == nil {
                // Unfortunately, rest has to be done by the user.
                paired = false
                userDefaults.setValue(false, forKey: K.isPairedKey)
                logger?.info("Completed unpairing, user defaults were reset")
            }
            else {
                logger?.error("Unpairing request has failed (\(error?.localizedDescription ?? "unknown cause"))")
            }
            isUnpairingRequested = false
        }
    }
    
    func unpair() {
        if connected {
            if let characteristic = ftsChars[ServiceIds.pairingWriteCh] {
                var request = 0xAD
                let requestData = Data(bytes: &request, count: 1)
                
                bluetoothPeripheral?.setNotifyValue(true, for: characteristic!)
                bluetoothPeripheral?.writeValue(requestData, for: characteristic!, type: .withResponse)
                isUnpairingRequested = true
            }
        }
        else {
            logger?.error("Unpairing failed: possible only if device is connected")
        }
    }
    //MARK: - DFU Control API
    func launchDfu() {
        guard dfuControlCharacteristic != nil else {
            logger?.error("DFU char is unavailable. Update will not happen")
            return
        }

        bluetoothPeripheral?.setNotifyValue(true, for: dfuControlCharacteristic!)
        
        let requestData = Data([UInt8(1)])
        bluetoothPeripheral?.writeValue(requestData, for: dfuControlCharacteristic!, type: .withResponse)
    }
    
    //MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        var state : String
        switch central.state {
        case .poweredOn:
            state = "Powered ON"
            if paired {
                startScanning()
            }
        case .poweredOff:
            state = "Powered OFF"
        case .resetting:
            state = "Resetting"
        case .unauthorized:
            state = "Unauthorized"
        case .unsupported:
            state = "Unsupported"
        default:
            state = "Unknown"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // TODO: at this point make sure that it's our peripheral (so ID is matching with what we paired to)
        if paired {
            connectPeripheral(peripheral: peripheral)
        }
        
        if let d = scannerDelegate {
            d.didDiscoverPeripheral(with: peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let name = peripheral.name {
            logger?.debug("Connected to: \(name)")
        } else {
            logger?.warning("Connected to device \(peripheral.identifier.uuidString)")
        }
        
        connected = true
        bluetoothPeripheral = peripheral
        bluetoothPeripheral!.delegate = self
        delegate?.didConnectPeripheral(deviceName: peripheral.name)
        DispatchQueue.main.async {
            self.uiUpdateDelegate?.didConnectionStatusUpdate(newState: .on)
        }
        connectDelegate?.didConnectToPeripheral(error: nil)
        peripheral.discoverServices([FTSServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger?.info("Disconnected from \(peripheral.name ?? "unknown device")")
        if error != nil {
            logger?.info("Disconnect error: \(error?.localizedDescription)")
        }
        
        connected = false
        isBASServiceFound = false
        isDFUServiceFound = false
        dfuControlCharacteristic = nil
        delegate?.didDisconnectPeripheral()
        serviceDiscoveryDelegate?.onDisconnect()
        DispatchQueue.main.async {
            self.uiUpdateDelegate?.didConnectionStatusUpdate(newState: .off)
        }
        bluetoothPeripheral!.delegate = nil
        bluetoothPeripheral = nil
        connectDelegate?.didDisconnectFromPeripheral()
        ftsChars.removeAll(keepingCapacity: false)
        updateBatteryLevel(with: 0)
        
        // Restart scanning to be able to catch up with Dictofun on it's next appearance
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: {
            self.startScanning()
        })
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard error == nil else {
            logger?.error("Central Manager did fail to connect to peripheral")
            return
        }

        logger?.error("Failed to connect to peripheral \(peripheral.identifier.uuidString)")
        
        connected = false
        delegate?.didDisconnectPeripheral()
        bluetoothPeripheral!.delegate = nil
        bluetoothPeripheral = nil
        connectDelegate?.didConnectToPeripheral(error: error)
    }
    
    //MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            logger?.error("Service discovery failed")
            return
        }

        var isFTSFound = false
        for aService: CBService in peripheral.services! {
            if aService.uuid.isEqual(FTSServiceUUID) {
                bluetoothPeripheral!.discoverCharacteristics(nil, for: aService)
                if !isBASServiceFound {
                    bluetoothPeripheral!.discoverServices([BASServiceUUID])
                }
                else if !isDFUServiceFound {
                    bluetoothPeripheral!.discoverServices([DFUServiceUUID])
                }
                isFTSFound = true
            }
            if aService.uuid.isEqual(BASServiceUUID) {
                isBASServiceFound = true
                bluetoothPeripheral!.discoverCharacteristics(nil, for: aService)
            }
            if aService.uuid.isEqual(DFUServiceUUID) {
                isDFUServiceFound = true
                bluetoothPeripheral!.discoverCharacteristics(nil, for: aService)
            }
        }
        
        //No FTS service discovered
        if !isFTSFound {
            logger?.error("FTS Service not found. Try to turn bluetooth Off and On again to clear the cache.")
            delegate?.peripheralNotSupported()
            cancelPeripheralConnection()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            logger?.error("Characteristics discovery failed (\(error!.localizedDescription)")
            return
        }
        
        if service.uuid.isEqual(FTSServiceUUID) {
            for characteristic : CBCharacteristic in service.characteristics! {
                let key = characteristic.uuid.uuidString
                if ftsCharsIDs.contains(key) {
//                    logger?.error("FTS Characteristic found: 0x\(key)")
                    ftsChars[characteristic.uuid.uuidString] = characteristic
                }
                else {
                    logger?.warning("Characteristic \(characteristic.uuid) is unknown")
                }
            }
            serviceDiscoveryDelegate?.didDiscoverServices()
        }
        if service.uuid.isEqual(BASServiceUUID) {
            for characteristic : CBCharacteristic in service.characteristics! {
                let uuid = characteristic.uuid.uuidString
                logger?.debug("BAS characteristic discovered: \(uuid)")
                
                readFrom(characteristic: characteristic)

                if characteristic.value != nil {
                    logger?.debug("BAS battery level: \(characteristic.value![0])")
                    updateBatteryLevel(with: Int(characteristic.value![0]))
                }
                else {
                    logger?.debug("BAS Battery level has not yet been set")
                }
            }
        }
        if service.uuid.isEqual(DFUServiceUUID) {
            for characteristic: CBCharacteristic in service.characteristics! {
                let uuid = characteristic.uuid.uuidString
                logger?.debug("DFU characteristic discovered: \(uuid)")
                if uuid == ServiceIds.DFU.dfuWithoutBondsCh {
                    dfuControlCharacteristic = characteristic
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {

            return
        }
        
        if characteristic.isNotifying {
            logger?.debug("Notifications enabled for characteristic: \(characteristic.uuid.uuidString)")
        } else {
            logger?.debug("Notifications disabled for characteristic: \(characteristic.uuid.uuidString)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            logger?.error("Writing value to characteristic has failed")
            if ftsChars[ServiceIds.pairingWriteCh] != nil && characteristic.isEqual(ftsChars[ServiceIds.pairingWriteCh]!!) {
                pairingCallback(error: error)
            }
            return
        }
//        logger?.debug("Data written to characteristic: \(characteristic.uuid.uuidString)")
        
        if let storedPairingCh = ftsChars[ServiceIds.pairingWriteCh] {
            if characteristic.uuid.uuidString == storedPairingCh?.uuid.uuidString {
                logger?.error("launching pairing callback with nil-error")
                pairingCallback(error: nil)
            }
        }
        else {
            logger?.error("no stored pairing char found")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        guard error == nil else {
            logger?.error("Writing value to descriptor has failed")
            return
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
//            logger?.error("Updating characteristic has failed")
            return
        }
        
        if let ftsDelegate = charNotifyDelegates[characteristic.uuid], let ftsChar = getCharByCBUUID(with: characteristic.uuid) {
            guard let bytesReceived = characteristic.value else {
                logger?.warning("Notification received from FTS Char: \(ftsChar.uuid.uuidString), with empty value")
                return
            }
            DispatchQueue.main.async {
                ftsDelegate.didCharNotify(with: ftsChar.uuid, and: bytesReceived, error: nil)
            }
        }
        if characteristic.uuid == CBUUID(string: ServiceIds.BAS.batteryLevelCh) {
            logger?.info("Battery level update", metadata: ["level":"\(characteristic.value![0])"])
            updateBatteryLevel(with: Int(characteristic.value![0]))
        }
    }
}

private extension Data {
    func split(by length: Int) -> [Data] {
        var startIndex = self.startIndex
        var chunks = [Data]()
        
        while startIndex < endIndex {
            let endIndex = index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            chunks.append(subdata(in: startIndex..<endIndex))
            startIndex = endIndex
        }
        
        return chunks
    }
}

private extension String {
    
    func split(by length: Int) -> [String] {
        var startIndex = self.startIndex
        var results = [Substring]()
        
        while startIndex < endIndex {
            let endIndex = index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            results.append(self[startIndex..<endIndex])
            startIndex = endIndex
        }
        
        return results.map { String($0) }
    }
    
}
