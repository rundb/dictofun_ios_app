// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import Foundation
import CoreBluetooth

// File is an 16-byte long ID
struct FileId {
    let value: Data
    init(value: Data) {
        self.value = value
        assert(value.count == 16)
    }
    
    var reversedValue: Data {
        var tmp = Data([])
        for b in value.reversed() {
            tmp.append(b)
        }
        return tmp
    }
    
    var name: String {
        if let validAsciiString = String(data: value, encoding: .ascii) {
            return validAsciiString
        }
        return "unknownunknown"
    }
    
    static func getIdByName(with name: String) -> FileId {
        guard let data = name.data(using: .ascii) else {
            NSLog("FileId: failed to convert ascii string to bytes")
            return FileId(value: Data([]))
        }
        return FileId(value: data)
    }
}

protocol CharNotificationDelegate {
    func didCharNotify(with char: CBUUID, and data: Data?, error: Error?)
}

protocol FtsToUiNotificationDelegate {
    func didReceiveFilesCount(with filesCount: Int)
    func didReceiveNextFileSize(with fileName: String, and fileSize: Int)
    func didReceiveFileDataChunk(with progressPercentage: Double)
    func didCompleteFileTransaction(name fileName: String, with duration: Int, and throughput: Int)
    func didReceiveFileSystemState(count filesCount: Int, occupied occupiedMemory: Int, free freeMemory: Int)
}

protocol BleServicesDiscoveryDelegate {
    func didDiscoverServices()
}

// Given the list of files on the device, detect those files that are not yet known to the application
protocol NewFilesDetectionDelegate {
    func detectNewFiles(with fileIds: [FileId]) -> [FileId]
}

/**
 This class implements all functions needed for file transfer service to operate, according to FTS specification:
 - get files' list from the device
 - get information about a particular file
 - download the file from the device
 */
class FileTransferService {
    
    private var bluetoothManager: BluetoothManager
    private var recordsManager: RecordsManager
    
    private let cpCharCBUUID = CBUUID(string: ServiceIds.FTS.controlPointCh)
    private let fileListCharCBUUID = CBUUID(string: ServiceIds.FTS.fileListCh)
    private let fileListNextCharCBUUID = CBUUID(string: ServiceIds.FTS.fileListNextCh)
    private let fileInfoCharCBUUID = CBUUID(string: ServiceIds.FTS.fileInfoCh)
    private let fileDataCharCBUUID = CBUUID(string: ServiceIds.FTS.fileDataCh)
    private let statusCharCBUUID = CBUUID(string: ServiceIds.FTS.statusCh)
    private let fsStatusCharCBUUID = CBUUID(string: ServiceIds.FTS.fsStatusCh)
    
    private let fileIdSize = 16
    private let fileCountFieldSize = 8
    
    private var fileIds: [FileId] = []
    
    var uiUpdateDelegate: FtsToUiNotificationDelegate?
    var newFilesDetectionDelegate: NewFilesDetectionDelegate?
    
    private struct CurrentFile {
        var fileId: FileId
        var size: Int
        var receivedSize: Int
        var data: Data
        var startTimestamp: Date?
        var endTimestamp: Date?
    }
    
    private var currentFile: CurrentFile
    
    static let minimalFileSize = 0x200
    
    init(with bluetoothManager: BluetoothManager, andRecordsManager recordsManager: RecordsManager) {
        self.bluetoothManager = bluetoothManager
        self.recordsManager = recordsManager
        
        self.currentFile = CurrentFile(fileId: FileId(value: Data([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])), size: 0, receivedSize: 0, data: Data([]))
        self.filesListCtx = FilesListContext()
        
        guard bluetoothManager.registerNotificationDelegate(forCharacteristic: fileListCharCBUUID, delegate: self) == nil else {
            assert(false)
            return
        }
        guard bluetoothManager.registerNotificationDelegate(forCharacteristic: fileListNextCharCBUUID, delegate: self) == nil else {
            assert(false)
            return
        }
        guard bluetoothManager.registerNotificationDelegate(forCharacteristic: fileInfoCharCBUUID, delegate: self) == nil else {
            assert(false)
            return
        }
        guard bluetoothManager.registerNotificationDelegate(forCharacteristic: fileDataCharCBUUID, delegate: self) == nil else {
            assert(false)
            return
        }
        guard bluetoothManager.registerNotificationDelegate(forCharacteristic: statusCharCBUUID, delegate: self) == nil else {
            assert(false)
            return
        }
        guard bluetoothManager.registerNotificationDelegate(forCharacteristic: fsStatusCharCBUUID, delegate: self) == nil else {
            assert(false)
            return
        }
        bluetoothManager.serviceDiscoveryDelegate = self
    }
    
    enum FtsOpResult: Error {
        case setupError
        case communicationError
    }
    
    func requestFilesList() -> Error? {
        
        let requestData = Data([UInt8(1)])
        
        guard bluetoothManager.setNotificationStateFor(characteristic: fileListCharCBUUID, toEnabled: true) == nil else {
            NSLog("FTS: failed to enable notifications for file list char \(fileListCharCBUUID.uuidString)")
            return .some(FtsOpResult.setupError)
        }
        guard bluetoothManager.setNotificationStateFor(characteristic: fileListNextCharCBUUID, toEnabled: true) == nil else {
            NSLog("FTS: failed to enable notifications for file list next char \(fileListNextCharCBUUID.uuidString)")
            return .some(FtsOpResult.setupError)
        }
        // At this point also enable notifications for status char, as this operation should always be the first in the chain of FTS calls
        guard bluetoothManager.setNotificationStateFor(characteristic: statusCharCBUUID, toEnabled: true) == nil else {
            NSLog("FTS: Failed to enable notifications for status char \(statusCharCBUUID.uuidString)")
            return .some(FtsOpResult.setupError)
        }
        
        guard bluetoothManager.writeTo(characteristic: cpCharCBUUID, with: requestData) == nil else {
            NSLog("FTS: Failed to send request to CP \(cpCharCBUUID.uuidString)")
            return .some(FtsOpResult.communicationError)
        }
        
        return nil
    }
    
    func getFileIds() -> [FileId] {
        return fileIds
    }
    
    func requestFileInfo(with fileId: FileId) -> Error? {
        var requestData = Data([UInt8(2)])
        requestData.append(fileId.value)
        
        guard bluetoothManager.setNotificationStateFor(characteristic: fileInfoCharCBUUID, toEnabled: true) == nil else {
            NSLog("FTS: Failed to enable notifications for file info char \(fileInfoCharCBUUID.uuidString)")
            return .some(FtsOpResult.setupError)
        }
        guard bluetoothManager.writeTo(characteristic: cpCharCBUUID, with: requestData) == nil else {
            NSLog("FTS: Failed to send request to CP Char \(cpCharCBUUID.uuidString)")
            return .some(FtsOpResult.communicationError)
        }
        self.currentFile.fileId = fileId
        self.currentFile.size = 0
        self.currentFile.data = Data([])
        return nil
    }
    
    func requestFileData(with fileId: FileId) -> Error? {
        var requestData = Data([UInt8(3)])
        requestData.append(fileId.value)
        
        guard bluetoothManager.setNotificationStateFor(characteristic: fileDataCharCBUUID, toEnabled: true) == nil else {
            NSLog("FTS: Failed to enable notifications for file data char \(fileDataCharCBUUID.uuidString)")
            return .some(FtsOpResult.setupError)
        }
        guard bluetoothManager.writeTo(characteristic: cpCharCBUUID, with: requestData) == nil else {
            NSLog("FTS: Failed to send request to CP char \(cpCharCBUUID.uuidString)")
            return .some(FtsOpResult.communicationError)
        }
        currentFile.data = Data([])
        currentFile.receivedSize = 0
        currentFile.startTimestamp = Date()
        return nil
    }
    
    func requestFileSystemStatus() -> Error? {
        let requestData = Data([UInt8(4)])
        
        NSLog("FTS: requesting file system status")
        
        guard bluetoothManager.setNotificationStateFor(characteristic: fileDataCharCBUUID, toEnabled: false) == nil else {
            return .some(FtsOpResult.setupError)
        }
        guard bluetoothManager.setNotificationStateFor(characteristic: fileListCharCBUUID, toEnabled: false) == nil else {
            return .some(FtsOpResult.setupError)
        }
        guard bluetoothManager.setNotificationStateFor(characteristic: fileListNextCharCBUUID, toEnabled: false) == nil else {
            return .some(FtsOpResult.setupError)
        }
        guard bluetoothManager.setNotificationStateFor(characteristic: fileInfoCharCBUUID, toEnabled: false) == nil else {
            return .some(FtsOpResult.setupError)
        }
        
        guard bluetoothManager.setNotificationStateFor(characteristic: fsStatusCharCBUUID, toEnabled: true) == nil else {
            NSLog("FTS: Failed to enable notifications for fs status char \(fsStatusCharCBUUID.uuidString)")
            return .some(FtsOpResult.setupError)
        }
        guard bluetoothManager.writeTo(characteristic: cpCharCBUUID, with: requestData) == nil else {
            NSLog("FTS: Failed to send request to CP char \(cpCharCBUUID.uuidString)")
            return .some(FtsOpResult.communicationError)
        }
        
        return nil
    }
    
    struct FileInformation: Decodable {
        let s: Int
        let f: Int?
        let c: Int?
    }
    
    struct FileSystemInformation {
        let free: Int
        let occupied: Int
        let count: Int
    }
    
    struct FilesListContext {
        var totalFilesCount: Int = 0
        var isNextFilesListCharNeeded: Bool = false
        static let maxFilesCount = 128
    }
    
    var filesListCtx: FilesListContext
    
    private func parseFilesList(with data: Data?) -> [FileId] {
        if let safeData = data {
            var filesCount = 0
            for i in 0...(fileCountFieldSize - 1) {
                filesCount += Int(safeData[i]) * (1 << i)
            }
            
            if safeData.count != filesCount * fileIdSize + fileCountFieldSize {
                if filesCount > FilesListContext.maxFilesCount {
                    NSLog("FTS: received a malformed files list (\(filesCount) > max files \(FilesListContext.maxFilesCount)")
                    return []
                }
                NSLog("FTS: count is bigger than actual size, so there are more files in fileListNext char")
                filesListCtx.totalFilesCount = filesCount
                filesListCtx.isNextFilesListCharNeeded = true
                filesCount = (safeData.count - fileCountFieldSize) / fileIdSize
                filesListCtx.totalFilesCount -= filesCount
            }

            let totalFilesCount = filesListCtx.isNextFilesListCharNeeded ? filesListCtx.totalFilesCount : filesCount
            NSLog("safedata size: \(safeData.count), filesCount: \(filesCount), totalFilesCount: \(totalFilesCount)")
            
            var fileIds: [FileId] = []
            NSLog("FTS: \(totalFilesCount) files are present on the Dictofun, in this char \(filesCount) files")
            if totalFilesCount == 0 {
                return []
            }
            for i in 0...(filesCount-1) {
                let fileIdBytes = safeData.subdata(
                    in: (fileCountFieldSize + fileIdSize * i)..<(fileCountFieldSize + fileIdSize * (i + 1)) )
                let fileId = FileId(value: fileIdBytes)
                fileIds.append(fileId)
            }
            return fileIds
        }
        return []
    }
    
    private func parseFilesListNext(with data: Data) -> [FileId] {
        if data.count % fileIdSize != 0 {
            NSLog("FTS files list next parser: invalid size of the list \(data.count) % \(fileIdSize) != 0")
            return []
        }
        let filesInListCount = data.count / fileIdSize
        var fileIds: [FileId] = []
        for i in 0...(filesInListCount - 1) {
            let fileIdBytes = data.subdata(in: (fileIdSize * i)..<(fileIdSize * (i + 1)) )
            let fileId = FileId(value: fileIdBytes)
            fileIds.append(fileId)
        }
        
        filesListCtx.totalFilesCount = (filesListCtx.totalFilesCount > filesInListCount) ? (filesListCtx.totalFilesCount - filesInListCount) : 0
        filesListCtx.isNextFilesListCharNeeded = (filesListCtx.totalFilesCount != 0)
        
        return fileIds
    }
    
    private func parseFileInformation(with data: Data?) -> FileInformation? {
        if let safeData = data {
            let expectedDataSize = Int(safeData[0]) + (Int(safeData[1]) << 8)
            if safeData.count != expectedDataSize + 2 {
                NSLog("Failed to parse file info: mismatch in size (\(safeData.count) != \(expectedDataSize + 2))")
                return nil
            }
            if let fileInfoRawString = String(bytes: safeData.subdata(in: 2..<(expectedDataSize + 2)), encoding: .ascii) {
                do {
                    let fileInfo: FileInformation = try JSONDecoder().decode(FileInformation.self, from: fileInfoRawString.data(using: .ascii)!)
                    return fileInfo
                }
                catch let DecodingError.keyNotFound(key, _) {
                    NSLog("FTS error: \(key) key was not found in the json")
                }
                catch {
                    NSLog("FTS error: general decoding error in JSONDecoder")
                }
                return nil
            }
            return nil
        }
        return nil
    }
    
    private func parseFileSystemInformation(with data: Data?) -> FileSystemInformation? {
        if let safeData = data {
            let expectedDataSize = Int(safeData[0]) + (Int(safeData[1]) << 8)
            if safeData.count != expectedDataSize  {
                NSLog("FTS: Failed to parse file system stats: mismatch in size (\(safeData.count) != \(expectedDataSize))")
                return nil
            }
            let freeSpaceRaw = safeData.subdata(in: 2..<6)
            let occupiedSpaceRaw = safeData.subdata(in: 6..<10)
            let countRaw = safeData.subdata(in: 10..<14)
            // FIXME: fix these withUnsafeBytes warnings appropriately
            let freeSpace = Int(UInt32(littleEndian: freeSpaceRaw.withUnsafeBytes { $0.pointee }))
            let occupiedSpace = Int(UInt32(littleEndian: occupiedSpaceRaw.withUnsafeBytes { $0.pointee }))
            let count = Int(UInt32(littleEndian: countRaw.withUnsafeBytes { $0.pointee }))
            let fileSystemInformation = FileSystemInformation(free: freeSpace, occupied: occupiedSpace, count: count)
            return fileSystemInformation
        }
        return nil
    }
}

// MARK: - CharNotificationDelegate
extension FileTransferService: CharNotificationDelegate {
    
    private func didReceiveFilesList(with data: Data) {
        let files = parseFilesList(with: data)
        NSLog("FTS: Received files' list: ")
        var fileNames: [String] = []
        for f in files {
            NSLog("\t\(f.name)")
            fileNames.append(f.name)
        }
        self.fileIds = files
        if filesListCtx.isNextFilesListCharNeeded
        {
            NSLog("New portion of files in the list is expected, so do nothing at this point")
            return
        }
        uiUpdateDelegate?.didReceiveFilesCount(with: files.count)
        
        // Fetch the list of existing records too. If new files discovered - request the first new file in the list
        guard let newFiles = newFilesDetectionDelegate?.detectNewFiles(with: files) else {
            NSLog("Error: newFilesDetectionDelegate has not been specified, aborting the execution.")
            assert(false)
            return
        }
        
        // TODO: replace with .map
        var newFileNames: [String] = []
        
        for f in newFiles {
            newFileNames.append(f.name)
        }
        
        if !newFileNames.isEmpty {
            NSLog("FTS.didReceiveFilesList: discovered \(newFileNames.count) new files on the device")
            let nextFileName = newFileNames.first
            let nextFileId = FileId.getIdByName(with: nextFileName!)

            NSLog("FTS::didReceiveFilesList - fetching newly found file \(nextFileId.name)")
            let requestResult = requestFileInfo(with: nextFileId)
            if requestResult != nil {
                NSLog("FTS::didReceiveFilesList: failed to request file information. Error: \(requestResult!.localizedDescription)")
            }
        }
        else {
            // Additionally by the end request the FS status data
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
                let result = self.requestFileSystemStatus()
                if result != nil {
                    NSLog("Failed to request file system status")
                }
            })
        }
    }
    
    private func didReceiveFilesListNext(with data: Data) {
        let files = parseFilesListNext(with: data)
        NSLog("FTS: Received continuation of files' list with \(files.count) entries")
        self.fileIds.append(contentsOf: files)
        if !filesListCtx.isNextFilesListCharNeeded {
            uiUpdateDelegate?.didReceiveFilesCount(with: fileIds.count)
            
            // Fetch the list of existing records too. If new files discovered - request the first new file in the list
            guard let newFiles = newFilesDetectionDelegate?.detectNewFiles(with: fileIds) else {
                NSLog("newFilesDetectionDelegate has not been specified, aborting")
                assert(false)
                return
            }
            var newFileNames: [String] = []
            for f in newFiles {
                newFileNames.append(f.name)
            }
            
            if !newFileNames.isEmpty {
                NSLog("FTS.didReceiveFilesListNext: discovered \(newFileNames.count) new files on the device")
                let nextFileId = FileId.getIdByName(with: newFileNames.first!)

                NSLog("FTS::didReceiveFilesList - fetching newly found file \(nextFileId.name)")
                let requestResult = requestFileInfo(with: nextFileId)
                if requestResult != nil {
                    NSLog("FTS::didReceiveFilesList: failed to request file information. Error: \(requestResult!.localizedDescription)")
                }
            }
        }
        else {
            NSLog("FTS did receive char next: waiting for \(filesListCtx.totalFilesCount) more files ")
        }
        
    }
    
    func didCharNotify(with char: CBUUID, and data: Data?, error: Error?) {
        if char.uuidString == ServiceIds.FTS.fileListCh {
            guard error == nil else {
                NSLog("FTS didCharNotify: error in file list notification. Error: \(error!.localizedDescription)")
                return
            }
            guard let safeData = data else {
                return
            }
            didReceiveFilesList(with: safeData)
        }
        else if char.uuidString == ServiceIds.FTS.fileListNextCh {
            NSLog("FTS didCharNotify for filesListNext")
            guard error == nil else {
                NSLog("FTS didCharNotify: error in file list next notification. Error: \(error!.localizedDescription)")
                return
            }
            guard let safeData = data else {
                return
            }
            didReceiveFilesListNext(with: safeData)
        }
        else if char.uuidString == ServiceIds.FTS.fileInfoCh {
            if let fileInfo = parseFileInformation(with: data) {
                NSLog("FTS: Requested file information: size \(fileInfo.s)")
                currentFile.size = fileInfo.s
                
                uiUpdateDelegate?.didReceiveNextFileSize(with: currentFile.fileId.name, and: currentFile.size)
                let requestResult = requestFileData(with: currentFile.fileId)
                if requestResult != nil {
                    NSLog("FTS didCharNotify: failed to request file data. Error: \(requestResult!.localizedDescription)")
                }
            }
            else {
                NSLog("FTS: Received file info is invalid")
            }
        }
        
        else if char.uuidString == ServiceIds.FTS.fileDataCh {
            if let safeData = data {
                currentFile.data.append(safeData)
                currentFile.receivedSize += safeData.count
                if currentFile.receivedSize == currentFile.size {
                    currentFile.endTimestamp = Date()
                    let transactionTime = currentFile.endTimestamp!.timeIntervalSinceReferenceDate - currentFile.startTimestamp!.timeIntervalSinceReferenceDate
                    let throughput = Double(currentFile.size) / transactionTime
                    NSLog(String(format: "Throughput: %0.1fbytes/second", throughput))
                    
                    var decodedAdpcm: Data = Data([])
                    
                    if currentFile.data.count >= FileTransferService.minimalFileSize {
                        decodedAdpcm = decodeAdpcm(from: currentFile.data.subdata(in: 0x100..<(currentFile.data.count - 1)))
                    }
                    
                    let storeResult = recordsManager.saveRecord(withRawWav: decodedAdpcm, andFileName: currentFile.fileId.name)
                    if nil != storeResult {
                        NSLog("FTS: record \(currentFile.fileId.name) failed to be saved, error: \(storeResult!.localizedDescription)")
                    }
                    NSLog("FTS: successfully stored record")
                    uiUpdateDelegate?.didCompleteFileTransaction(name: currentFile.fileId.name, with: Int(transactionTime), and: Int(throughput))
                    let reqResult = requestFilesList()
                    if reqResult != nil {
                        NSLog("FTS: failed to re-request files list")
                    }
                }
                else {
                    let progress = Double(currentFile.receivedSize) / Double(currentFile.size)
                    uiUpdateDelegate?.didReceiveFileDataChunk(with: progress)
                }
            }
        }
        
        else if char.uuidString == ServiceIds.FTS.fsStatusCh {
            NSLog("Received file system status")
            if let safeData = data {
                let fsInfo = parseFileSystemInformation(with: safeData)
                if let safeFsInfo = fsInfo {
                    NSLog("Received File System info: \(safeFsInfo.free) is free, \(safeFsInfo.occupied) occupied, with total of \(safeFsInfo.count) files")
                    uiUpdateDelegate?.didReceiveFileSystemState(count: safeFsInfo.count, occupied: safeFsInfo.occupied, free: safeFsInfo.free)
                }
                else {
                    NSLog("FTS: Failed to parse received FileSystem info")
                }
            }
        }
        
        else if char.uuidString == ServiceIds.FTS.statusCh {
            if let safeData = data {
                if safeData.count == 0 {
                    NSLog("FTS: error: 0-length status data received")
                    return
                }
                if safeData[0] == 2 {
                    NSLog("\tFTS: file not found error")
                }
                else if safeData[0] == 3 {
                    NSLog("\tFTS: file system corruption error")
                }
                else if safeData[0] == 4 {
                    NSLog("\tFTS: transaction aborted error")
                }
                else if safeData[0] == 5 {
                    NSLog("\tFTS: generic error")
                }
            }
        }
        else {
            NSLog("FTS notification: unknown")
        }
    }
}

extension FileTransferService: BleServicesDiscoveryDelegate {
    
    func didDiscoverServices() {
        let result = self.requestFilesList()
        if result != nil {
            NSLog("FTS: service discovery callback - files' request has failed")
        }
    }
}
