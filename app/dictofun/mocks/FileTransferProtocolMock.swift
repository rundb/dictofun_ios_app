//
//  FileTransferProtocolMock.swift
//  dictofun
//
//  Created by Roman on 17.05.23.
//

import Foundation

/// Mock implementation of File Transfer Service Protocol
class FileTransferServiceMock: FileTransferServiceProtocol
{
    private var filesList: Array<String>? = nil
    private var targetFileSize: Int? = nil
    private var targetFileData: Array<UInt8>? = nil
    private var isDFConnected: Bool = false
    
    // Mock values'setters
    func setFilesList(list: Array<String>?) {
        filesList = list
    }
    
    // Mock implementations
    func getFilesList() -> Array<String>? {
        return filesList
    }
    
    func getFileSize(name: String) -> Int? {
        return targetFileSize
    }
    
    func getFileData(name: String) -> Array<UInt8>? {
        return targetFileData
    }
    
    func getFSStatus() -> (filesCount: Int, occupiedMemory: Int, freeMemory: Int)? {
        return nil
    }
    
    func getFileTransferProgress() -> Int? {
        return 10
    }
    
    func isConnected() -> Bool {
        return isDFConnected
    }
    

}
