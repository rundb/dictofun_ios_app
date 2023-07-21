import Foundation
import CoreBluetooth

protocol CharNotificationDelegate {
    func didCharNotify(with char: CBUUID, and data: Data?, error: Error?)
}

protocol FtsToUiNotificationDelegate {
    func didReceiveFilesCount(with filesCount: Int)
    func didReceiveNextFileSize(with fileName: String, and fileSize: Int)
    func didReceiveFileDataChunk(with progressPercentage: Double)
    func didCompleteFileTransaction(name fileName: String, with duration: Int, and throughput: Int)
}

/**
 This class implements all functions needed for file transfer service to operate, according to FTS specification:
 - get files' list from the device
 - get information about a particular file
 - download the file from the device
 */
class FileTransferService {
    
    private var bluetoothManager: BluetoothManager
    
    private let cpCharCBUUID = CBUUID(string: ServiceIds.FTS.controlPointCh)
    private let fileListCharCBUUID = CBUUID(string: ServiceIds.FTS.fileListCh)
    private let fileInfoCharCBUUID = CBUUID(string: ServiceIds.FTS.fileInfoCh)
    private let fileDataCharCBUUID = CBUUID(string: ServiceIds.FTS.fileDataCh)
    private let statusCharCBUUID = CBUUID(string: ServiceIds.FTS.statusCh)
    private let fsStatusCharCBUUID = CBUUID(string: ServiceIds.FTS.fsStatusCh)
    
    private let fileIdSize = 8
    
    private var fileIds: [FileId] = []
    
    var uiUpdateDelegate: FtsToUiNotificationDelegate?
    
    private struct CurrentFile {
        var fileId: FileId
        var size: Int
        var receivedSize: Int
        var data: Data
        var startTimestamp: Date?
        var endTimestamp: Date?
    }
    
    private var currentFile: CurrentFile
    
    init(with bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
        self.currentFile = CurrentFile(fileId: FileId(value: Data([0,0,0,0,0,0,0,0])), size: 0, receivedSize: 0, data: Data([]))
        
        guard bluetoothManager.registerNotificationDelegate(forCharacteristic: fileListCharCBUUID, delegate: self) == nil else {
            print("failed to register notification delegate for \(fileListCharCBUUID.uuidString)")
            assert(false)
            return
        }
        guard bluetoothManager.registerNotificationDelegate(forCharacteristic: fileInfoCharCBUUID, delegate: self) == nil else {
            print("failed to register notification delegate for \(fileInfoCharCBUUID.uuidString)")
            assert(false)
            return
        }
        guard bluetoothManager.registerNotificationDelegate(forCharacteristic: fileDataCharCBUUID, delegate: self) == nil else {
            print("failed to register notification delegate for \(fileDataCharCBUUID.uuidString)")
            assert(false)
            return
        }
        guard bluetoothManager.registerNotificationDelegate(forCharacteristic: statusCharCBUUID, delegate: self) == nil else {
            print("failed to register notification delegate for \(statusCharCBUUID.uuidString)")
            assert(false)
            return
        }
        guard bluetoothManager.registerNotificationDelegate(forCharacteristic: fsStatusCharCBUUID, delegate: self) == nil else {
            print("failed to register notification delegate for \(fsStatusCharCBUUID.uuidString)")
            assert(false)
            return
        }
    }
    
    enum FtsOpResult: Error {
        case setupError
        case communicationError
    }
    
    func requestFilesList() -> Error? {
        
        let requestData = Data([UInt8(1)])
        
        guard bluetoothManager.setNotificationStateFor(characteristic: fileListCharCBUUID, toEnabled: true) == nil else {
            print("Failed to enable notifications for char \(fileListCharCBUUID.uuidString)")
            return .some(FtsOpResult.setupError)
        }
        // At this point also enable notifications for status char, as this operation should always be the first in the chain of FTS calls
        guard bluetoothManager.setNotificationStateFor(characteristic: statusCharCBUUID, toEnabled: true) == nil else {
            print("Failed to enable notifications for char \(statusCharCBUUID.uuidString)")
            return .some(FtsOpResult.setupError)
        }
        
        guard bluetoothManager.writeTo(characteristic: cpCharCBUUID, with: requestData) == nil else {
            print("Failed to send request to  \(cpCharCBUUID.uuidString)")
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
            print("Failed to enable notifications for char \(fileInfoCharCBUUID.uuidString)")
            return .some(FtsOpResult.setupError)
        }
        guard bluetoothManager.writeTo(characteristic: cpCharCBUUID, with: requestData) == nil else {
            print("Failed to send request to  \(cpCharCBUUID.uuidString)")
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
            print("Failed to enable notifications for char \(fileDataCharCBUUID.uuidString)")
            return .some(FtsOpResult.setupError)
        }
        guard bluetoothManager.writeTo(characteristic: cpCharCBUUID, with: requestData) == nil else {
            print("Failed to send request to  \(cpCharCBUUID.uuidString)")
            return .some(FtsOpResult.communicationError)
        }
        currentFile.data = Data([])
        currentFile.receivedSize = 0
        currentFile.startTimestamp = Date()
        return nil
    }
    
    func requestFileSystemStatus() -> Error? {
        let requestData = Data([UInt8(4)])
        
        guard bluetoothManager.setNotificationStateFor(characteristic: fsStatusCharCBUUID, toEnabled: true) == nil else {
            print("Failed to enable notifications for char \(fsStatusCharCBUUID.uuidString)")
            return .some(FtsOpResult.setupError)
        }
        guard bluetoothManager.writeTo(characteristic: cpCharCBUUID, with: requestData) == nil else {
            print("Failed to send request to  \(cpCharCBUUID.uuidString)")
            return .some(FtsOpResult.communicationError)
        }
        
        return nil
    }
    
    // File (atm) is an 8-byte long ID
    struct FileId {
        let value: Data
        init(value: Data) {
            self.value = value
            assert(value.count == 8)
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
            return "unknown"
        }
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
    
    private func parseFilesList(with data: Data?) -> [FileId] {
        if let safeData = data {
            var filesCount = 0
            for i in 0...(fileIdSize-1) {
                filesCount += Int(safeData[i]) * (1 << i)
            }
            
            if safeData.count != filesCount * fileIdSize + 8 {
                print("FTS: received a malformed files' count")
                return []
            }
            var fileIds: [FileId] = []
            print("FTS: \(filesCount) files are present on the Dictofun")
            if filesCount == 0 {
                return []
            }
            for i in 0...(filesCount-1) {
                let fileIdBytes = safeData.subdata(in: (fileIdSize * (i+1))..<(fileIdSize * (i + 2)) )
                let fileId = FileId(value: fileIdBytes)
                fileIds.append(fileId)
            }
            return fileIds
        }
        return []
    }
    
    private func parseFileInformation(with data: Data?) -> FileInformation? {
        if let safeData = data {
            let expectedDataSize = Int(safeData[0]) + (Int(safeData[1]) << 8)
            if safeData.count != expectedDataSize + 2 {
                print("Failed to parse file info: mismatch in size (\(safeData.count) != \(expectedDataSize + 2))")
                return nil
            }
            if let fileInfoRawString = String(bytes: safeData.subdata(in: 2..<(expectedDataSize + 2)), encoding: .ascii) {
                do {
                    let fileInfo: FileInformation = try JSONDecoder().decode(FileInformation.self, from: fileInfoRawString.data(using: .ascii)!)
                    return fileInfo
                }
                catch let DecodingError.keyNotFound(key, _) {
                    print("error: \(key) key was not found in the json")
                }
                catch {
                    print("error: general decoding error in JSONDecoder")
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
                print("Failed to parse file system stats: mismatch in size (\(safeData.count) != \(expectedDataSize))")
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
    func didCharNotify(with char: CBUUID, and data: Data?, error: Error?) {
        if char.uuidString == ServiceIds.FTS.fileListCh {
            let files = parseFilesList(with: data)
            print("Received files' list: ")
            for f in files {
                print("\t\(f.value.map { String(format: "%02x", $0) }.joined() )")
            }
            self.fileIds = files
            uiUpdateDelegate?.didReceiveFilesCount(with: files.count)
        }
        if char.uuidString == ServiceIds.FTS.fileInfoCh {
            if let fileInfo = parseFileInformation(with: data) {
                print("Requested file information: size \(fileInfo.s)")
                currentFile.size = fileInfo.s
                
                uiUpdateDelegate?.didReceiveNextFileSize(with: currentFile.fileId.name, and: currentFile.size)
            }
            else {
                print("Received file info is invalid")
            }
        }
        
        if char.uuidString == ServiceIds.FTS.fileDataCh {
            if let safeData = data {
                print("receiving file data (\(safeData.count) bytes)")
                currentFile.data.append(safeData)
                currentFile.receivedSize += safeData.count
                if currentFile.receivedSize == currentFile.size {
                    print("file reception complete")
                    currentFile.endTimestamp = Date()
                    let transactionTime = currentFile.endTimestamp!.timeIntervalSinceReferenceDate - currentFile.startTimestamp!.timeIntervalSinceReferenceDate
                    let throughput = Double(currentFile.size) / transactionTime
                    print(String(format: "Throughput: %0.1fbytes/second", throughput))
                    uiUpdateDelegate?.didCompleteFileTransaction(name: currentFile.fileId.name, with: Int(transactionTime), and: Int(throughput))
                }
                else {
                    print("receiving: \(currentFile.receivedSize)/\(currentFile.size)")
                    let progress = Double(currentFile.receivedSize) / Double(currentFile.size)
                    uiUpdateDelegate?.didReceiveFileDataChunk(with: progress)
                }
            }
        }
        
        if char.uuidString == ServiceIds.FTS.fsStatusCh {
            if let safeData = data {
                print("received file system status, \(safeData.count) bytes")
                let fsInfo = parseFileSystemInformation(with: safeData)
                if let safeFsInfo = fsInfo {
                    print("Received File System info: \(safeFsInfo.free) is free, \(safeFsInfo.occupied) occupied, with total of \(safeFsInfo.count) files")
                }
                else {
                    print("Failed to parse received FileSystem info")
                }
            }
        }
        
        if char.uuidString == ServiceIds.FTS.statusCh {
            if let safeData = data {
                print("received FTS status update:")
                if safeData.count == 0 {
                    print("error: 0-length status data received")
                    return
                }
                if safeData[0] == 2 {
                    print("\tfile not found error")
                }
                else if safeData[0] == 3 {
                    print("\tfile system corruption error")
                }
                else if safeData[0] == 4 {
                    print("\ttransaction aborted error")
                }
                else if safeData[0] == 5 {
                    print("\tgeneric error")
                }
            }
        }
    }
}
