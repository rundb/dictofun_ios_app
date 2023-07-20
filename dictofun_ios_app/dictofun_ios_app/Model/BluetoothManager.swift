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

enum BluetoothManagerError: Error {
    case cannotFindPeripheral
    
    var localizedDescription: String {
        "Can not find peripheral"
    }
    
}

class BluetoothManager: NSObject, CBPeripheralDelegate, CBCentralManagerDelegate {
    
    //MARK: - Delegate Properties
    var delegate: BluetoothManagerDelegate?
    var logger: Logger?
    var scannerDelegate: ScannerDelegate?
    var connectDelegate: ConnectDelegate?
    var pairDelegate: PairDelegate?
    
    //MARK: - Class Properties
    fileprivate let FTSServiceUUID             : CBUUID
    
    fileprivate var centralManager              : CBCentralManager
    fileprivate var bluetoothPeripheral         : CBPeripheral?
    
    var userDefaults: UserDefaults = .standard
    
    // FTS Characteristics
    let ftsCharsIDs: Set = [
        ServiceIds.FTS.controlPointCh,
        ServiceIds.FTS.statusCh,
        ServiceIds.FTS.fsStatusCh,
        ServiceIds.FTS.fileDataCh,
        ServiceIds.FTS.fileInfoCh,
        ServiceIds.FTS.fileListCh,
        ServiceIds.pairingWriteCh
    ]
    var ftsChars: [String:CBCharacteristic?] = [:]
    
    fileprivate var connected = false
    var paired = false
    private var connectingPeripheral: CBPeripheral!
    
    private let btQueue = DispatchQueue(label: "com.nRF-toolbox.bluetoothManager", qos: .utility)
    
    // MARK: - public API intended for use by services
    enum CharOpError: Error {
        case notFound
        case notImplemented
        case other
    }
    
    func writeTo(characteristic char: CBUUID, with data: Data) -> Error? {
        return .some(CharOpError.notImplemented)
    }
    
    func readFrom(characteristic char: CBUUID) -> Data? {
        return nil
    }
    
    func setNotificationStateFor(characteristic char: CBUUID, toEnabled state: Bool) -> Error? {
        return .some(CharOpError.notImplemented)
    }
    
    func registerNotificationDelegate(forCharacteristic char: CBUUID, delegate: CharNotificationDelegate?) -> Error? {
        return .some(CharOpError.notImplemented)
    }
    
    //MARK: - BluetoothManager API
    
    required init(withManager aManager : CBCentralManager = CBCentralManager()) {
        centralManager = aManager
        FTSServiceUUID          = CBUUID(string: ServiceIds.FTS.service)

        super.init()
        
        centralManager.delegate = self
        initUserDefaults()
    }
    
    func initUserDefaults() {
        let isPairedValue = userDefaults.value(forKey: K.isPairedKey)
        if isPairedValue == nil {
            userDefaults.setValue(false, forKey: K.isPairedKey)
            paired = false
            log(withLevel: .info, andMessage: "User default value for paired not found, resetting")
        }
        else {
            log(withLevel: .info, andMessage: "User default value for paired found, value: \(isPairedValue as! Bool ? "true" : "false")")
            paired = isPairedValue as! Bool
        }
    }
    
    func startScanning() {
        log(withLevel: .info, andMessage: "start scanning")
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
        
        // we assign the bluetoothPeripheral property after we establish a connection, in the callback
        if let name = aPeripheral.name {
            log(withLevel: .verbose, andMessage: "Connecting to: \(name)...")
        } else {
            log(withLevel: .verbose, andMessage: "Connecting to device...")
        }
        log(withLevel: .debug, andMessage: "centralManager.connect(peripheral, options:nil)")
        
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
            log(withLevel: .warning, andMessage: "Peripheral not set")
            return
        }
        if connected {
            log(withLevel: .verbose, andMessage: "Disconnecting...")
        } else {
            log(withLevel: .verbose, andMessage: "Cancelling connection...")
        }
        log(withLevel: .debug, andMessage: "centralManager.cancelPeripheralConnection(peripheral)")
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
        guard error == nil else {
            log(withLevel: .error, andMessage: "Pairing has failed. Aborting")
            print(error!.localizedDescription)
            pairDelegate?.didPairWithPeripheral(error: error)
            return
        }
        log(withLevel: .info, andMessage: "Pairing successful, updating user defaults")
        paired = true
        userDefaults.setValue(paired, forKey: K.isPairedKey)
        pairDelegate?.didPairWithPeripheral(error: nil)
    }
    
    func unpair() {
        // Unfortunately, rest has to be done by the user.
        paired = false
        userDefaults.setValue(false, forKey: K.isPairedKey)
        log(withLevel: .info, andMessage: "Completed unpairing, user defaults were reset")
    }

    
    //MARK: - Logger API
    
    func log(withLevel aLevel : LogType, andMessage aMessage : String) {
        logger?.log(level: aLevel,message: aMessage)
    }
    
    func logError(error anError : Error) {
        logger?.log(level: .error, message: "Error: \(anError.localizedDescription)")
    }
    
    //MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        var state : String
        switch central.state {
        case .poweredOn:
            state = "Powered ON"
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
        
        log(withLevel: .info, andMessage: "[Callback] Central Manager did update state to: \(state)")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        log(withLevel: .info, andMessage: "discovered \(peripheral.identifier) with RSSI \(RSSI.intValue)")
        if let d = scannerDelegate {
            d.didDiscoverPeripheral(with: peripheral)
        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log(withLevel: .debug, andMessage: "[Callback] Central Manager did connect peripheral")
        if let name = peripheral.name {
            log(withLevel: .info, andMessage: "Connected to: \(name)")
        } else {
            log(withLevel: .info, andMessage: "Connected to device")
        }
        
        connected = true
        bluetoothPeripheral = peripheral
        bluetoothPeripheral!.delegate = self
        delegate?.didConnectPeripheral(deviceName: peripheral.name)
        connectDelegate?.didConnectToPeripheral(error: nil)
        log(withLevel: .verbose, andMessage: "Discovering services...")
        log(withLevel: .debug, andMessage: "peripheral.discoverServices([\(FTSServiceUUID.uuidString)])")
        peripheral.discoverServices([FTSServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if case .some(let e) = error {
            log(withLevel: .debug, andMessage: "[Callback] Central Manager did disconnect peripheral")
            logError(error: e)
        }
        log(withLevel: .debug, andMessage: "[Callback] Central Manager did disconnect peripheral successfully")
        log(withLevel: .info, andMessage: "Disconnected")
        
        connected = false
        delegate?.didDisconnectPeripheral()
        bluetoothPeripheral!.delegate = nil
        bluetoothPeripheral = nil
        connectDelegate?.didDisconnectFromPeripheral()
        ftsChars.removeAll(keepingCapacity: false)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard error == nil else {
            log(withLevel: .debug, andMessage: "[Callback] Central Manager did fail to connect to peripheral")
            logError(error: error!)
            return
        }
        log(withLevel: .debug, andMessage: "[Callback] Central Manager did fail to connect to peripheral without errors")
        log(withLevel: .info, andMessage: "Failed to connect")
        
        connected = false
        delegate?.didDisconnectPeripheral()
        bluetoothPeripheral!.delegate = nil
        bluetoothPeripheral = nil
        connectDelegate?.didConnectToPeripheral(error: error)
    }
    
    //MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            log(withLevel: .warning, andMessage: "Service discovery failed")
            logError(error: error!)
            //TODO: Disconnect?
            return
        }
        
        log(withLevel: .info, andMessage: "Services discovered")
        
        for aService: CBService in peripheral.services! {
            if aService.uuid.isEqual(FTSServiceUUID) {
                log(withLevel: .verbose, andMessage: "FTS Service found")
                log(withLevel: .verbose, andMessage: "Discovering characteristics...")
                log(withLevel: .debug, andMessage: "peripheral.discoverCharacteristics(nil, for: \(aService.uuid.uuidString))")
                bluetoothPeripheral!.discoverCharacteristics(nil, for: aService)
                return
            }
        }
        
        //No UART service discovered
        log(withLevel: .warning, andMessage: "FTS Service not found. Try to turn bluetooth Off and On again to clear the cache.")
        delegate?.peripheralNotSupported()
        cancelPeripheralConnection()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            log(withLevel: .warning, andMessage: "Characteristics discovery failed")
            logError(error: error!)
            return
        }
        log(withLevel: .info, andMessage: "Characteristics discovered")
        
        if service.uuid.isEqual(FTSServiceUUID) {
            for characteristic : CBCharacteristic in service.characteristics! {
                let key = characteristic.uuid.uuidString
                if ftsCharsIDs.contains(key) {
                    log(withLevel: .verbose, andMessage: "FTS Characteristic found: 0x\(key)")
                    ftsChars[characteristic.uuid.uuidString] = characteristic
                }
                else {
                    log(withLevel: .warning, andMessage: "Characteristic \(characteristic.uuid) is unknown")
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            log(withLevel: .warning, andMessage: "Enabling notifications failed")
            logError(error: error!)
            return
        }
        
        if characteristic.isNotifying {
            log(withLevel: .info, andMessage: "Notifications enabled for characteristic: \(characteristic.uuid.uuidString)")
        } else {
            log(withLevel: .info, andMessage: "Notifications disabled for characteristic: \(characteristic.uuid.uuidString)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            log(withLevel: .warning, andMessage: "Writing value to characteristic has failed")
            logError(error: error!)
            if ftsChars[ServiceIds.pairingWriteCh] != nil && characteristic.isEqual(ftsChars[ServiceIds.pairingWriteCh]!!) {
                pairingCallback(error: error)
            }
            return
        }
        log(withLevel: .info, andMessage: "Data written to characteristic: \(characteristic.uuid.uuidString)")
        
        if let storedPairingCh = ftsChars[ServiceIds.pairingWriteCh] {
            if characteristic.uuid.uuidString == storedPairingCh?.uuid.uuidString {
                log(withLevel: .info, andMessage: "launching pairing callback with nil-error")
                pairingCallback(error: nil)
            }
            else {
                log(withLevel: .warning, andMessage: "mismatch between stored and actual char ID")
            }
        }
        else {
            log(withLevel: .warning, andMessage: "no stored pairing char found")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        guard error == nil else {
            log(withLevel: .warning, andMessage: "Writing value to descriptor has failed")
            logError(error: error!)
            return
        }
        log(withLevel: .info, andMessage: "Data written to descriptor: \(descriptor.uuid.uuidString)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            log(withLevel: .warning, andMessage: "Updating characteristic has failed")
            logError(error: error!)
            return
        }
        
        // try to print a friendly string of received bytes if they can be parsed as UTF8
        guard let bytesReceived = characteristic.value else {
            log(withLevel: .info, andMessage: "Notification received from: \(characteristic.uuid.uuidString), with empty value")
            log(withLevel: .application, andMessage: "Empty packet received")
            return
        }
        
        log(withLevel: .info, andMessage: "Notification received from: \(characteristic.uuid.uuidString), with value: 0x\(bytesReceived.hexString)")
        if let validUTF8String = String(data: bytesReceived, encoding: .utf8) {
            log(withLevel: .application, andMessage: "\"\(validUTF8String)\" received")
        } else {
            log(withLevel: .application, andMessage: "\"0x\(bytesReceived.hexString)\" received")
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


//
//    /**
//     * This method sends the given test to the UART RX characteristic.
//     * Depending on whether the characteristic has the Write Without Response or Write properties the behaviour is different.
//     * In the latter case the Long Write may be used. To enable it you have to change the flag below in the code.
//     * Otherwise, in both cases, texts longer than 20 (MTU) bytes (not characters) will be splitted into up-to 20-byte packets.
//     *
//     * - parameter aText: text to be sent to the peripheral using Nordic UART Service
//     */
//    func send(text aText : String) {
//        guard let uartRXCharacteristic = uartRXCharacteristic else {
//            log(withLevel: .warning, andMessage: "UART RX Characteristic not found")
//            return
//        }
//
//        // Check what kind of Write Type is supported. By default it will try Without Response.
//        // If the RX charactereisrtic have Write property the Write Request type will be used.
//        let type: CBCharacteristicWriteType = uartRXCharacteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
//        let mtu  = bluetoothPeripheral?.maximumWriteValueLength(for: type) ?? 20
//
//        // The following code will split the text into packets
//        aText.split(by: mtu).forEach {
//            send(text: $0, withType: type)
//        }
//    }
//
//    /**
//     * Sends the given text to the UART RX characteristic using the given write type.
//     * This method does not split the text into parts. If the given write type is withResponse
//     * and text is longer than 20-bytes the long write will be used.
//     *
//     * - parameters:
//     *     - aText: text to be sent to the peripheral using Nordic UART Service
//     *     - aType: write type to be used
//     */
//    func send(text aText : String, withType aType : CBCharacteristicWriteType) {
//        guard uartRXCharacteristic != nil else {
//            log(withLevel: .warning, andMessage: "UART RX Characteristic not found")
//            return
//        }
//
//        let typeAsString = aType == .withoutResponse ? ".withoutResponse" : ".withResponse"
//        let data = aText.data(using: String.Encoding.utf8)!
//
//        // Do some logging
//        log(withLevel: .verbose, andMessage: "Writing to characteristic: \(uartRXCharacteristic!.uuid.uuidString)")
//        log(withLevel: .debug, andMessage: "peripheral.writeValue(0x\(data.hexString), for: \(uartRXCharacteristic!.uuid.uuidString), type: \(typeAsString))")
//        bluetoothPeripheral!.writeValue(data, for: uartRXCharacteristic!, type: aType)
//        // The transmitted data is not available after the method returns. We have to log the text here.
//        // The callback peripheral:didWriteValueForCharacteristic:error: is called only when the Write Request type was used,
//        // but even if, the data is not available there.
//        log(withLevel: .application, andMessage: "\"\(aText)\" sent")
//    }
//
//    /// Sends the given command to the UART characteristic
//    /// - Parameter aCommand: command that will be send to UART peripheral.
//    func send(command aCommand: UARTCommandModel) {
//        guard let uartRXCharacteristic = self.uartRXCharacteristic else {
//            log(withLevel: .warning, andMessage: "UART RX Characteristic not found")
//            return
//        }
//
//        // Check what kind of Write Type is supported. By default it will try Without Response.
//        // If the RX characteristic have Write property the Write Request type will be used.
//        let type: CBCharacteristicWriteType = uartRXCharacteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
//        let mtu = bluetoothPeripheral?.maximumWriteValueLength(for: type) ?? 20
//
//        let data = aCommand.data.split(by: mtu)
//        log(withLevel: .verbose, andMessage: "Writing to characteristic: \(uartRXCharacteristic.uuid.uuidString)")
//        let typeAsString = type == .withoutResponse ? ".withoutResponse" : ".withResponse"
//        data.forEach {
//            self.bluetoothPeripheral!.writeValue($0, for: uartRXCharacteristic, type: type)
//            log(withLevel: .debug, andMessage: "peripheral.writeValue(0x\($0.hexString), for: \(uartRXCharacteristic.uuid.uuidString), type: \(typeAsString))")
//        }
//        log(withLevel: .application, andMessage: "Sent command: \(aCommand.title)")
//
//    }
//
//    func send(macro: UARTMacro) {
//
//        btQueue.async {
//            macro.commands.forEach { (element) in
//                switch element {
//                case let command as UARTCommandModel:
//                    self.send(command: command)
//                case let timeInterval as UARTMacroTimeInterval:
//                    usleep(useconds_t(timeInterval.milliseconds * 1000))
//                default:
//                    break
//                }
//            }
//        }
//    }
