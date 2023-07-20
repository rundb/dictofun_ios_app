import Foundation
import CoreBluetooth

protocol CharNotificationDelegate {
    func didCharNotify(with char: CBUUID, and data: Data?, error: Error?)
}

/**
    This class implements all functions needed for file transfer service to operate, according to FTS specification:
     - get files' list from the device
     - get information about a particular file
     - download the file from the device
 */
class FileTransferService : CharNotificationDelegate {
    
    private var bluetoothManager: BluetoothManager
    
    private let cpCharCBUUID = CBUUID(string: ServiceIds.FTS.controlPointCh)
    private let fileListCharCBUUID = CBUUID(string: ServiceIds.FTS.fileListCh)
    private let fileInfoCharCBUUID = CBUUID(string: ServiceIds.FTS.fileInfoCh)
    
    private let fileIdSize = 8
    
    private var fileIds: [FileId] = []
    
    init(with bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
        
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
        
        print("\t\(requestData.map { String(format: "%02x", $0) }.joined() )")
        print("\(requestData.count)")
        
        guard bluetoothManager.setNotificationStateFor(characteristic: fileInfoCharCBUUID, toEnabled: true) == nil else {
            print("Failed to enable notifications for char \(fileInfoCharCBUUID.uuidString)")
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
    }
    
    struct FileInformation: Decodable {
        let s: Int
        let f: Int
        let c: Int
    }
    
    func didCharNotify(with char: CBUUID, and data: Data?, error: Error?) {
        if char.uuidString == ServiceIds.FTS.fileListCh {
            let files = parseFilesList(with: data)
            print("Received files' list: ")
            for f in files {
                print("\t\(f.value.map { String(format: "%02x", $0) }.joined() )")
            }
            self.fileIds = files
        }
        if char.uuidString == ServiceIds.FTS.fileInfoCh {
            if let fileInfo = parseFileInformation(with: data) {
                print("Requested file information: size \(fileInfo.s), freq \(fileInfo.f), codec \(fileInfo.c)")
            }
            else {
                print("Received file info is invalid")
            }
        }
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
                print("Failed to parse file info: mismatch in size (\(safeData.count) != \(expectedDataSize + 1))")
                return nil
            }
            if let fileInfoRawString = String(bytes: safeData.subdata(in: 2..<(expectedDataSize + 2)), encoding: .ascii) {
                let fileInfo: FileInformation = try! JSONDecoder().decode(FileInformation.self, from: fileInfoRawString.data(using: .ascii)!)
                return fileInfo
            }
            return nil
        }
        return nil
    }
    
    
}
