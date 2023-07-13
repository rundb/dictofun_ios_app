//
//  FileTransferServiceProtocol.swift
//  dictofun
//
//  Created by Roman on 17.05.23.
//

import Foundation
import CoreBluetooth

/**
 This protocol describes expected behavior from a BLE FTS implementation
 */
protocol FileTransferServiceProtocol
{
    func getFilesList() -> Array<String>?
    func getFileSize(name: String) -> Int?
    func getFileData(name: String) -> Array<UInt8>?
    func getFSStatus() -> (filesCount: Int, occupiedMemory: Int, freeMemory: Int)?
    
    // Helper functions
    /// Returns file transfer progress in integer percents, or nil, if no active transfers exist
    func getFileTransferProgress() -> Int?
    func isConnected() -> Bool
    
    func getServiceUUID() -> CBUUID
}

/**
 This implementation of FTS uses API of BLE Controller.
 First version is fully synchronous, and it can be an issue sooner or later, so it might get changed into delegates-based API
 */
class FileTransferService: FileTransferServiceProtocol
{
    private var bleContext: BleContext?
    private var bleController: BleControlProtocol?
    
    private let serviceCBUUIDString: String = "a0451001-b822-4820-8782-bd8faf68807b"

    func registerBleComponents(bleContext: inout BleContext, bleController: BleControlProtocol)
    {
        self.bleContext = bleContext
        self.bleController = bleController
    }
    
    func getServiceUUID() -> CBUUID {
        return CBUUID(string: serviceCBUUIDString)
    }
    
    func getFilesList() -> Array<String>? {
        // subscribe to files_list characteristic
        
        // write to the CP characteristic
        
        // wait until notification from files list has arrived
        
        // convert binary data to the files list
        
        return nil
    }
    
    func getFileSize(name: String) -> Int? {
        return nil
    }
    
    func getFileData(name: String) -> Array<UInt8>? {
        return nil
    }
    
    func getFSStatus() -> (filesCount: Int, occupiedMemory: Int, freeMemory: Int)? {
        return nil
    }
    
    func getFileTransferProgress() -> Int? {
        return nil
    }
    
    func isConnected() -> Bool {
        return bleContext!.bleState == .connected
    }
    
    
}
