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
    func didCompleteFileTransaction(name fileName: String, with duration: Int)
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


// MARK: - FtsEventNotificationDelegate
extension FTSManager: FtsEventNotificationDelegate {
    
    private func launchNextFtsJob(with jobs: [FtsJob]) {
        if jobs.isEmpty {
            NSLog("No more jobs to execute")
            return
        }
        for job in jobs {
            if job.shouldFetchMetadata {
                let reqResult = fts.requestFileInfo(with: job.fileId)
                if reqResult != nil {
                    NSLog("Failed to request file info for \(job.fileId.name), error \(reqResult!.localizedDescription)")
                }
                else {
                    NSLog("Requested file meta data for \(job.fileId.name)")
                }
                return
            }
        }
        for job in jobs {
            if job.shouldFetchData {
                let reqResult = fts.requestFileData(with: job.fileId, and: job.fileSize)
                if reqResult != nil {
                    NSLog("Failed to request file data for \(job.fileId.name), error \(reqResult!.localizedDescription)")
                }
                else {
                    NSLog("Requested file data for \(job.fileId.name)")
                }
                return
            }
        }
        NSLog("FTSManager: no FTS jobs left to launch")
    }
    
    func didReceiveFilesList(with files: [FileId]) {
        uiNotificationDelegate?.didReceiveFilesCount(with: files.count)
        // pass the list of files to the records manager and get the list of IDs that needs to be fetched
        let ftsJobs = rm.defineFtsJobs(with: files)
        if !ftsJobs.isEmpty {
            for job in ftsJobs {
                NSLog("newly discovered record: \(job.fileId.name) : \(job.shouldFetchMetadata) : \(job.shouldFetchData) : \(job.fileSize)")
            }
            launchNextFtsJob(with: ftsJobs)
            return
        }
    }
    
    func didReceiveFileSize(with fileId: FileId, and fileSize: Int) {
        uiNotificationDelegate?.didReceiveNextFileSize(with: fileId.name, and: fileSize)
        rm.setRecordRawSize(id: fileId, fileSize)
        let ftsJobs = rm.defineFtsJobs()
        launchNextFtsJob(with: ftsJobs)
    }
    
    func didReceiveFileDataChunk(with fileId: FileId, and progressPercentage: Double) {
        uiNotificationDelegate?.didReceiveFileDataChunk(with: progressPercentage)
        rm.setDownloadProgress(id: fileId, Float(progressPercentage))
    }
    
    private func getFileNameFromFileId(with fileId: FileId) -> String {
        return fileId.name + ".wav"
    }
    
    func didCompleteFileTransaction(name fileId: FileId, with duration: Int, fileType type: FileType, _ data: Data) {
        uiNotificationDelegate?.didCompleteFileTransaction(name: fileId.name, with: duration)
        // 0. decode adpcm, if needed
        var record: Data = Data([])
        if type == .adpcmData {
            record = decodeAdpcm(from: data)
        }
        else {
            record.append(data)
        }
        // 1. store the raw file in the filesystem
        let savedRecordUrl = afm.saveRecord(withRawWav: record, andFileName: getFileNameFromFileId(with: fileId))
        if savedRecordUrl == nil {
            NSLog("Failed to store the record")
            return
        }
        
        // 2. store the raw URL in the database
        rm.setRecordRawUrl(id: fileId, url: savedRecordUrl!)
        rm.setDownloadDuration(id: fileId, Float(duration))
        
        // 3. get list of the next jobs that need to be executed
        let ftsJobs = rm.defineFtsJobs()
        launchNextFtsJob(with: ftsJobs)
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
