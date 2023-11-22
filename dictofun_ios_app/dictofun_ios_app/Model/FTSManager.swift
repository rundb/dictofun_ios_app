// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import Foundation

protocol FtsToUiNotificationDelegate {
    func didReceiveFilesCount(with filesCount: Int)
    func didReceiveNextFileSize(with fileName: String, and fileSize: Int)
    func didReceiveFileDataChunk(with fileId: FileId, and progressPercentage: Double)
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
    let tm: TranscriptionManager
    
    var currentTranscriptionJob: TranscriptionJob?
    
    var uiNotificationDelegate: FtsToUiNotificationDelegate?
    
    var isFilesListRequestCompleted = false
    
    init(ftsService fts: FileTransferService, audioFilesManager afm: AudioFilesManager, recordsManager rm: RecordsManager, transcriptionManager tm: TranscriptionManager) {
        self.fts = fts
        self.afm = afm
        self.rm = rm
        self.tm = tm
        
        getBluetoothManager().serviceDiscoveryDelegate = self
    }
    
    func launchTranscriptions() {
        var transcrtiptionJobs = rm.getTranscriptionJobs()
        if !transcrtiptionJobs.isEmpty
        {
            for i in 0...transcrtiptionJobs.count - 1 {
                let url = transcrtiptionJobs[i].fileUrl
                let actualUrl = getAudioFilesManager().getRecordURL(withFileName: url.lastPathComponent)
                transcrtiptionJobs[i].fileUrl = actualUrl!
                NSLog("transcription job:\(transcrtiptionJobs[i].uuid)} \(transcrtiptionJobs[i].fileUrl)")
            }
        }
        if !transcrtiptionJobs.isEmpty {
            let job = transcrtiptionJobs[0]
            let transcriptionRequestResult = tm.requestTranscription(url: job.fileUrl, callback: transcriptionCallback)
            if transcriptionRequestResult != nil {
                NSLog("failed to launch transcription")
                return
            }
            currentTranscriptionJob = job
        }
        else {
            currentTranscriptionJob = nil
        }
    }
    
    func transcriptionCallback(with error: TranscriptionManager.CompletionError?, and text: String?) {
        if error != nil {
            NSLog("FTS Manager: transcription failed")
            guard let job = currentTranscriptionJob else {
                NSLog("Fatal error: currently active transcription is nil")
                return
            }
            if error == TranscriptionManager.CompletionError.recognitionError {
                rm.setRecordTranscription(with: job.uuid, and: "--- no speech detected ---")
            }
            return
        }
        else {
            NSLog("FTS Manager: received transcription \(text!)")
            guard let job = currentTranscriptionJob else {
                NSLog("Fatal error: currently active transcription is nil")
                return
            }
            rm.setRecordTranscription(with: job.uuid, and: text!)
        }
        // Continue with launching transcripting
        launchTranscriptions()
    }
}


// MARK: - FtsEventNotificationDelegate
extension FTSManager: FtsEventNotificationDelegate {
    
    private func launchNextFtsJob(with jobs: [FtsJob]) {
        if jobs.isEmpty {
            NSLog("No more jobs to execute")
            let reportResult = fts.reportReceivingCompletion()
            if reportResult != nil {
                NSLog("Failed to report reception completion")
            }
            launchTranscriptions()
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
                NSLog("record from device: \(job.fileId.name) : \(job.shouldFetchMetadata) : \(job.shouldFetchData) : \(job.fileSize)")
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
        uiNotificationDelegate?.didReceiveFileDataChunk(with: fileId, and: progressPercentage)
        rm.setDownloadProgress(id: fileId, Float(progressPercentage))
    }
    
    private func getFileNameFromFileId(with fileId: FileId) -> String {
        return fileId.name + ".wav"
    }
    
    private func convertFtsStringToDate(with raw: String) -> Date {
        
        let year = String(raw[raw.index(raw.startIndex, offsetBy: 4)...raw.index(raw.startIndex, offsetBy: 5)])
        let month = String(raw[raw.index(raw.startIndex, offsetBy: 6)...raw.index(raw.startIndex, offsetBy: 7)])
        let day = String(raw[raw.index(raw.startIndex, offsetBy: 8)...raw.index(raw.startIndex, offsetBy: 9)])
        let hour = String(raw[raw.index(raw.startIndex, offsetBy: 10)...raw.index(raw.startIndex, offsetBy: 11)])
        let minute = String(raw[raw.index(raw.startIndex, offsetBy: 12)...raw.index(raw.startIndex, offsetBy: 13)])
        let second = String(raw[raw.index(raw.startIndex, offsetBy: 14)...raw.index(raw.startIndex, offsetBy: 15)])
        
        let formattedDate = "\(year)-\(month)-\(day) \(hour):\(minute):\(second)"
        let format = "yy-MM-dd HH:mm:ss"
        
        let formatter = DateFormatter()
        formatter.dateFormat = format
        let result = formatter.date(from: formattedDate)
        guard result != nil else {
            NSLog("Failed to convert the received file ID to a valid date. Returning current time")
            return Date.now
        }
        
        return result!
    }
    
    func didCompleteFileTransaction(name fileId: FileId, with duration: Int, fileType type: FileType, _ data: Data) {
        uiNotificationDelegate?.didCompleteFileTransaction(name: fileId.name, with: duration)

        // 0. decode adpcm, if needed
        var record: Data = Data([])
        if type == .adpcmData {
            record = decodeAdpcm(from: data)
            rm.setRecordSize(id: fileId, record.count)
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
        
        let recordDate = convertFtsStringToDate(with: fileId.name)
        NSLog("Record's creation date/time: \(recordDate)")
        
        // TODO: replace this with a function that uses Audio framework of iOS. Currently hardcoded bytes per second
        let recordBytesPerSecond = Float(7872.0)
        let recordDuration = Float(data.count) / recordBytesPerSecond
        rm.setRecordDuration(id: fileId, duration: recordDuration)
        
        // 2. store the raw URL in the database
        rm.completeFileReception(id: fileId, url: savedRecordUrl!)
        rm.setDownloadDuration(id: fileId, Float(duration))
        rm.setRecordTime(id: fileId, timestamp: recordDate)
        
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
        if !isFilesListRequestCompleted {
            NSLog("requesting files list")
            let result = fts.requestFilesList()
            if result != nil {
                NSLog("FTS: service discovery callback - files' request has failed")
            }
            isFilesListRequestCompleted = true
        }
        else {
            NSLog("second request upon service discovery in this session. Do nothing")
        }
    }
    
    func onDisconnect() {
        isFilesListRequestCompleted = false
    }
}
