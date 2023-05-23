//
//  FileTransferServiceProtocol.swift
//  dictofun
//
//  Created by Roman on 17.05.23.
//

import Foundation

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
}

/**
 This implementation of FTS uses API of BLE Controller.
 First version is fully synchronous, and it can be an issue sooner or later, so it might get changed into delegates-based API
 */
class FileTransferService: FileTransferServiceProtocol
{
    private var bleContext: BleContext
    private var bleController: BleControlProtocol
    
    init(bleContext: BleContext, bleController: BleControlProtocol) {
        self.bleContext = bleContext
        self.bleController = bleController
    }
    
    func getFilesList() -> Array<String>? {
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
        return bleContext.bleState == .connected
    }
    
    
}
