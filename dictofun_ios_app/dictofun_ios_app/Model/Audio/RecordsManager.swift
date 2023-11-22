// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import Foundation
import CoreData
import UIKit

/**
 This entity is responsible for the management of full lifecycle of a record.
 */
class RecordsManager {
    
    let context: NSManagedObjectContext
    
    private let downloadStatusMetadataUnknown = "metadata-unknown"
    private let downloadStatusNotStarted = "not-started"
    private let downloadStatusRunning = "running"
    private let downloadStatusCompleted = "completed"
    
    init() {
        // add references to files' manager and db manager
        context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    }
    
    private func saveContext() {
        do {
            try context.save()
        }
        catch {
            NSLog("Failed to save db context: \(error)")
        }
    }
    
    private func getMetaData(_ predicate: NSPredicate?) -> [MetaData] {
        let request = MetaData.fetchRequest()
        if predicate != nil {
            request.predicate = predicate
        }
        var result: [MetaData] = []
        do {
            result = try context.fetch(request)
        }
        catch {
            NSLog("getMetaData(): CoreData fetch failed. Error: \(error)")
            return []
        }
        return result
    }
    
    private func getTranscriptions(_ predicate: NSPredicate?) -> [Transcription] {
        let request = Transcription.fetchRequest()
        if (predicate != nil) {
            request.predicate = predicate
        }
        var result: [Transcription] = []
        do {
            result = try context.fetch(request)
        }
        catch {
            NSLog("getTranscriptions(): CoreData fetch failed. Error: \(error)")
            return []
        }
        return result
    }
    
    private func getDownloadMetaData(_ predicate: NSPredicate?) -> [DownloadMetaData] {
        let request = DownloadMetaData.fetchRequest()
        if predicate != nil {
            request.predicate = predicate
        }
        var result: [DownloadMetaData] = []
        do {
            result = try context.fetch(request)
        }
        catch {
            NSLog("getDownloadMetaData(): CoreData fetch failed. Error: \(error)")
            return []
        }
        return result
    }
    
    private func getDownloadMetaDataByFileId(_ fileId: FileId) -> DownloadMetaData? {
        let uuidRequestResult = getMetaData(NSPredicate(format: "name == %@", fileId.name))
        if uuidRequestResult.isEmpty {
            NSLog("Record with name \(fileId.name) is not found.")
            return nil
        }

        guard let uuid = uuidRequestResult[0].id else {
            NSLog("Failed to fetch correct UUID for record \(fileId.name)")
            return nil
        }
        
        // get meta data object corresponding to the file ID
        let downloadMetaData = getDownloadMetaData(NSPredicate(format: "id == %@", uuid.uuidString))
        if downloadMetaData.isEmpty {
            // TODO: it may be a valid case, consider creating a new entry
            NSLog("DownloadMetaData fetch result is empty. ATM we do not continue from this point. Name: \(fileId.name)")
            return nil
        }
        
        return downloadMetaData[0]
    }
    
    
    // Methods of initial record's lifecycle
    // Initiate entries in all tables and fill in all non-optional fields with initial values
    func registerRecord(_ fileId: FileId) {
        // TODO: make sure that this record doesn't exist yet
        let metaData = MetaData(context: context)
        let downloadMetaData = DownloadMetaData(context: context)
        let transcription = Transcription(context: context)
        let newUUID = UUID()
        metaData.id = newUUID
        metaData.is_deleted = false
        downloadMetaData.id = newUUID
        downloadMetaData.status = downloadStatusMetadataUnknown
        transcription.id = newUUID
        transcription.isCompleted = false
        metaData.name = fileId.name
        NSLog("new DB entry: \(newUUID.uuidString):\(fileId.name)")
        saveContext()
    }
    
    
    func getRecords() -> [MetaData] {
        
        return getMetaData(nil)
    }
    
    func setRecordRawSize(id fileId: FileId, _ size: Int) {
        // create a fetch request based on the file ID

        guard let downloadMetaDataEntry = getDownloadMetaDataByFileId(fileId) else {
            return
        }
        
        downloadMetaDataEntry.rawFileSize = Int32(size)
        downloadMetaDataEntry.status = downloadStatusNotStarted
        
        NSLog("Storing record size: \(fileId.name) - \(size)")
        
        // save the DB context
        saveContext()
    }
    
    func setRecordSize(id fileId: FileId, _ size: Int) {
        let records = getMetaData(NSPredicate(format: "name == %@", fileId.name))
        if records.isEmpty {
            NSLog("Error: attempt to set size \(size) to non-existent record \(fileId.name)")
            return
        }
        records[0].size = Int32(size)
        saveContext()
    }
    
    func completeFileReception(id fileId: FileId, url recordUrl: URL) {
        // fetch the metadata object, based on the file ID
        let recordEntry = getMetaData(NSPredicate(format: "name == %@", fileId.name))
        let downloadMetaDataEntry = getDownloadMetaDataByFileId(fileId)
        
        guard !(recordEntry.isEmpty || downloadMetaDataEntry == nil) else {
            NSLog("Failed to store record URL: got an empty metadata/download metadata")
            return
        }
        
        // set the raw file stored URL
        recordEntry[0].filesystemUrl = recordUrl
        downloadMetaDataEntry!.status = downloadStatusCompleted
        downloadMetaDataEntry!.progress = 100.0
        
        // save the context
        saveContext()
    }
    
    func getRecordUrl(id fileId: FileId) -> URL? {
        let records = getMetaData(NSPredicate(format: "name == %@", fileId.name))
        if records.isEmpty {
            return nil
        }
        return records[0].filesystemUrl
        
    }
    func setRecordTime(id fileId: FileId, timestamp datetime: Date) {
        let records = getMetaData(NSPredicate(format: "name == %@", fileId.name))
        if records.isEmpty {
            return
        }
        
        records[0].creationTime = datetime
        saveContext()
    }
    
    func setRecordDuration(id fileId: FileId, duration durationSeconds: Float) {
        let records = getMetaData(NSPredicate(format: "name == %@", fileId.name))
        if records.isEmpty {
            return
        }
        
        records[0].duration = durationSeconds
        saveContext()
    }
    
    // Metadata of download progress
    func setDownloadProgress(id fileId: FileId, _ progress: Float) {
        guard let downloadMetaDataEntry = getDownloadMetaDataByFileId(fileId) else {
            return
        }
        
        downloadMetaDataEntry.progress = progress * 100
        downloadMetaDataEntry.status = downloadStatusRunning
        
        saveContext()
    }
    
    func setDownloadDuration(id fileId: FileId, _ duration: Float) {
        guard let downloadMetaDataEntry = getDownloadMetaDataByFileId(fileId) else {
            return
        }
        
        downloadMetaDataEntry.duration = duration
        saveContext()
    }
    
    // Analyze the list of the file IDs received from the device.
    // Define what needs to be done for each of the detected records
    // For some - metadata needs to be fetched, for some - data needs to be fetched
    func defineFtsJobs(with fileIds: [FileId]) -> [FtsJob] {
        let recordsMetadataList = getRecords()
        if !recordsMetadataList.isEmpty {
            NSLog("existing records: ")
        }
        var existingFileIds: [FileId] = []
        for r in recordsMetadataList {
            if r.name != nil {
                let fileId = FileId.getIdByName(with: r.name!)
                existingFileIds.append(fileId)
            }
        }
        var ftsJobs: [FtsJob] = []
        for f in fileIds {
            var doesRecExist = false
            var isMetadataFetchNeeded = false
            var isDataFetchNeeded = false
            var recordSize = 0
            // todo: replace with logic based on use of a set
            for r in existingFileIds {
                if r.name == f.name {
                    doesRecExist = true
                }
            }
            if !doesRecExist {
                // todo: create new entry in the database
                NSLog("registering a new record in the database")
                registerRecord(f)
                isMetadataFetchNeeded = true
                isDataFetchNeeded = true
            }
            else {
                for r in recordsMetadataList {
                    if r.name == f.name {
                        let downloadMetaData = getDownloadMetaData(NSPredicate(format: "id == %@", r.id!.uuidString))
                        if downloadMetaData.isEmpty {
                            NSLog("WARNING: DownloadMetaData entry doesn't exist for record \(f.name)")
                            isMetadataFetchNeeded = true
                            isDataFetchNeeded = true
                        }
                        else {
                            let downloadMetaDataEntry = downloadMetaData[0]
                            if downloadMetaDataEntry.status == downloadStatusMetadataUnknown {
                                isMetadataFetchNeeded = true
                                isDataFetchNeeded = false
                            }
                            else if downloadMetaDataEntry.status != downloadStatusCompleted {
                                isMetadataFetchNeeded = false
                                isDataFetchNeeded = true
                                recordSize = Int(downloadMetaDataEntry.rawFileSize)
                            }
                        }
                    }
                }
            }
            ftsJobs.append(FtsJob(fileId: f, shouldFetchMetadata: isMetadataFetchNeeded, shouldFetchData: isDataFetchNeeded, fileSize: recordSize))
        }
        return ftsJobs
    }
    
    // In case if this method is called without arguments, it has to fetch the records
    // in the database that either are missing the metadata or the data
    // TODO: add correct handling, when metadata about a record exists on the phone, but not anymore on the device
    func defineFtsJobs() -> [FtsJob] {
        let downloadMetaData = getDownloadMetaData(nil)
        var jobs: [FtsJob] = []
        for entry in downloadMetaData {
            if !(entry.status == downloadStatusMetadataUnknown || entry.status != downloadStatusCompleted) {
                continue
            }
            
            guard let recordUUID = entry.id else {
                return []
            }
            let metadata = getMetaData(NSPredicate(format: "id == %@", recordUUID.uuidString))
            guard !metadata.isEmpty else {
                return []
            }
            let fileId = FileId.getIdByName(with: metadata[0].name!)
                        
            if entry.status == downloadStatusMetadataUnknown {
                jobs.append(FtsJob(fileId: fileId, shouldFetchMetadata: true, shouldFetchData: false, fileSize: 0))
            }
            else if entry.status != downloadStatusCompleted {
                jobs.append(FtsJob(fileId: fileId, shouldFetchMetadata: false, shouldFetchData: true, fileSize: Int(entry.rawFileSize)))
            }
        }
        return jobs
    }
    
    // Transcription-related methods
    
    func setRecordTranscription(with id: UUID, and text: String) {
        let uuidRequestResult = getTranscriptions(NSPredicate(format: "id == %@", id.uuidString))
        if uuidRequestResult.isEmpty {
            NSLog("Transcription entry with UUID \(id.uuidString) is not found.")
            return
        }
        uuidRequestResult[0].transcriptionText = text
        uuidRequestResult[0].isCompleted = true
        // TODO: add functionality of defining language
        uuidRequestResult[0].language = "en"
        saveContext()
    }
    
    func finalizeTranscription(with fileId: FileId) {}
    func getUntranscribedRecords() -> [FileId] { return [] }
    
    func deleteRecord(with uuid: UUID) {
        let metaData = getMetaData(NSPredicate(format: "id == %@", uuid.uuidString))
        
        if metaData.isEmpty {
            return
        }
        metaData[0].is_deleted = true
        saveContext()
    }
    
    func forceDeleteAllRecords() {
        let metadataFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "MetaData")
        let metadataDeleteRequest = NSBatchDeleteRequest(fetchRequest: metadataFetchRequest)

        let downloadMetadataFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "DownloadMetaData")
        let downloadMetadataDeleteRequest = NSBatchDeleteRequest(fetchRequest: downloadMetadataFetchRequest)

        let transcriptionFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Transcription")
        let transcriptionDeleteRequest = NSBatchDeleteRequest(fetchRequest: transcriptionFetchRequest)

        do {
            try context.execute(metadataDeleteRequest)
            NSLog("metadata table request succeeded")
            try context.execute(downloadMetadataDeleteRequest)
            NSLog("download metadata table request succeeded")
            try context.execute(transcriptionDeleteRequest)
            NSLog("transcription table request succeeded")
            try context.save()
            NSLog("context save has succeeded")
        }
        catch let error {
            NSLog("CoreData remove attempt has failed. Error: \(error)")
        }
    }
    
    func deleteAllRecords() {
        let metadatas = getMetaData(nil)
        for m in metadatas {
            m.is_deleted = true
        }
        saveContext()
    }
    
    func getRecordsList() -> [RecordViewData] {
        var metadatas = getMetaData(NSPredicate(format: "is_deleted == false"))
        
        metadatas.sort(by: {
            if $0.creationTime != nil && $1.creationTime != nil {
                return $0.creationTime! > $1.creationTime!
            }
            if $0.name != nil && $1.name != nil {
                return $0.name! > $1.name!
            }
            return true
        })
        var records: [RecordViewData] = []

        for m in metadatas {
            if m.size < 200 && m.size != 0 {
                // Glitch of the current dictofun state - short recs have to be removed for the visual representation
                continue
            }
            let uuid = m.id!
            let downloadMetaData = getDownloadMetaData(NSPredicate(format: "id == %@", uuid.uuidString))[0]
            let status = downloadMetaData.status
            
            let transcriptionData = getTranscriptions(NSPredicate(format: "id == %@", uuid.uuidString))[0]
            var transcription: String? = nil
            if transcriptionData.isCompleted {
                transcription = transcriptionData.transcriptionText
            }
            
            
            if status == downloadStatusMetadataUnknown {
                let recordViewData = RecordViewData(url: nil, uuid: uuid, creationDate: nil, durationSeconds: nil, isDownloaded: false, isSizeKnown: false, name: m.name!, progress: 0, transcription: transcription)
                records.append(recordViewData)
            }
            else if status == downloadStatusCompleted {
                let recordViewData = RecordViewData(url: m.filesystemUrl, uuid: uuid, creationDate: m.creationTime, durationSeconds: Int(m.duration), isDownloaded: true, isSizeKnown: true, name: m.name!, progress: 100, transcription: transcription)
                records.append(recordViewData)
            }
            else {
                var progress = 0
                if downloadMetaData.progress .isFinite {
                    progress = Int(downloadMetaData.progress)
                }
                let recordViewData = RecordViewData(url: nil, uuid: uuid, creationDate: nil, durationSeconds: nil, isDownloaded: false, isSizeKnown: true, name: m.name!, progress: progress, transcription: transcription)
                records.append(recordViewData)
            }
            
        }
        return records
    }
    
    func getTranscriptionJobs() -> [TranscriptionJob]
    {
        let transcriptions = getTranscriptions(nil)
        var jobs: [TranscriptionJob] = []
        for t in transcriptions {
            let uuid = t.id!
            if t.isCompleted {
                continue
            }
            let metaData = getMetaData(NSPredicate(format: "id == %@", uuid.uuidString))[0]
            let url = metaData.filesystemUrl
            if url == nil || metaData.size < 400 {
                continue
            }
            let job = TranscriptionJob(uuid: uuid, fileUrl: url!, transcription: nil, isCompleted: false)
            jobs.append(job)
        }
        return jobs
    }
}
