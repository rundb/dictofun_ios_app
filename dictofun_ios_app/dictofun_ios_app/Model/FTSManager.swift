//
//  FTSManager.swift
//  dictofun_ios_app
//
//  Created by Roman on 31.08.23.
//

import Foundation

protocol FtsToUiNotificationDelegate {
    func didReceiveFilesCount(with filesCount: Int)
    func didReceiveNextFileSize(with fileName: String, and fileSize: Int)
    func didReceiveFileDataChunk(with progressPercentage: Double)
    func didCompleteFileTransaction(name fileName: String, with duration: Int, and throughput: Int)
    func didReceiveFileSystemState(count filesCount: Int, occupied occupiedMemory: Int, free freeMemory: Int)
}

/**
 This module connects FileTransferService to the application
 */
class FTSManager {
    let fts: FileTransferService
    let afm: AudioFilesManager
    let rm: RecordsManager
    
    var uiNotificationDelegate: FtsToUiNotificationDelegate?
    
    init(ftsService fts: FileTransferService, audioFilesManager afm: AudioFilesManager, recordsManager rm: RecordsManager) {
        self.fts = fts
        self.afm = afm
        self.rm = rm
        
        getBluetoothManager().serviceDiscoveryDelegate = self
    }
}

// MARK: - NewFilesDetectionDelegate
// TODO: move the detection logic itself to the records' manager, leaving only a connection at this point
extension FTSManager: NewFilesDetectionDelegate {
    func storeNewFile(with fileId: FileId, type fileType: FileType, and data: Data) -> Error? {
        if fileType == .wavData {
            return afm.saveRecord(withRawWav: data, andFileName: fileId.name)
        }
        return nil
    }
    
    func detectNewFiles(with fileIds: [FileId]) -> [FileId] {
        NSLog("warning: detectNewFiles should be moved to another abstraction level")
        
        let existingRecords = afm.getRecordsList()
        var existingFileNames: [String] = []
        for r in existingRecords {
            existingFileNames.append(r.name)
        }
        
        var fileNames: [String] = []
        for f in fileIds {
            fileNames.append(f.name)
        }
        
        let newFileNames = findNewFiles(new: fileNames, existing: existingFileNames)
        var newFileIds: [FileId] = []
        for name in newFileNames {
            newFileIds.append( FileId.getIdByName(with: name))
        }
        if newFileIds.count > 0 {
            rm.registerRecord(newFileIds[0])
            let recs = rm.getRecords()
            for r in recs {
                NSLog("ROTU record uuid: \(r.uuidString)")
            }
        }
        return newFileIds
    }
    
    private func findNewFiles(new lhs: [String], existing rhs: [String]) -> [String] {
        NSLog("warning: findNewFiles should be moved to another abstraction level")
        var rhsSet: Set<String> = []
        for name in rhs {
            rhsSet.insert(name)
        }
        var result: [String] = []
        for name in lhs {
            if !rhsSet.contains(name) {
                result.append(name)
            }
        }
        return result
    }
}

// MARK: - FtsEventNotificationDelegate
// TODO: add notifications to the records manager too, if needed 
extension FTSManager: FtsEventNotificationDelegate {
    func didReceiveFilesCount(with filesCount: Int) {
        uiNotificationDelegate?.didReceiveFilesCount(with: filesCount)
    }
    
    func didReceiveNextFileSize(with fileId: FileId, and fileSize: Int) {
        uiNotificationDelegate?.didReceiveNextFileSize(with: fileId.name, and: fileSize)
    }
    
    func didReceiveFileDataChunk(with progressPercentage: Double) {
        uiNotificationDelegate?.didReceiveFileDataChunk(with: progressPercentage)
    }
    
    func didCompleteFileTransaction(name fileId: FileId, with duration: Int, and throughput: Int) {
        uiNotificationDelegate?.didCompleteFileTransaction(name: fileId.name, with: duration, and: throughput)
    }
    
    func didReceiveFileSystemState(count filesCount: Int, occupied occupiedMemory: Int, free freeMemory: Int) {
        uiNotificationDelegate?.didReceiveFileSystemState(count: filesCount, occupied: occupiedMemory, free: freeMemory)
    }
}

// MARK: - BleServicesDiscoveryDelegate
extension FTSManager: BleServicesDiscoveryDelegate {
    func didDiscoverServices() {
        let result = fts.requestFilesList()
        if result != nil {
            NSLog("FTS: service discovery callback - files' request has failed")
        }
    }
}
