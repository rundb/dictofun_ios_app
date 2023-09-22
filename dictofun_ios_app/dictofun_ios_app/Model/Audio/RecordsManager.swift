//
//  RecordsManager.swift
//  dictofun_ios_app
//
//  Created by Roman on 31.08.23.
//

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
    
    
    // Methods of initial record's lifecycle
    // Initiate entries in all tables and fill in all non-optional fields with initial values
    func registerRecord(_ fileId: FileId) {
        // TODO: make sure that this record doesn't exist yet
        let metaData = MetaData(context: context)
        let downloadMetaData = DownloadMetaData(context: context)
        let transcription = Transcription(context: context)
        let newUUID = UUID()
        metaData.id = newUUID
        downloadMetaData.id = newUUID
        downloadMetaData.status = downloadStatusMetadataUnknown
        transcription.id = newUUID
        transcription.isCompleted = false
        metaData.name = fileId.name
        NSLog("new DB entry: \(newUUID.uuidString):\(fileId.name)")
        saveContext()
    }
    
    
    func getRecords() -> [MetaData] {
//        deleteAllRecords()
        let request = MetaData.fetchRequest()
        do {
            let recordsEntries = try context.fetch(request)
            return recordsEntries
        }
        catch {
            NSLog("Failed to fetch db context: \(error)")
            return []
        }
    }
    
    func getDownloadMetaData(with uuid: UUID) -> DownloadMetaData? {
        let uuidPredicate = NSPredicate(format: "id == %@", uuid.uuidString)

        let request = DownloadMetaData.fetchRequest()
        request.predicate = uuidPredicate
        var result: [DownloadMetaData] = []
        do {
            result = try context.fetch(request)
        }
        catch {
            NSLog("Failed to fetch download metadata for \(uuid), error: \(error)")
        }
        if !result.isEmpty {
            return result[0]
        }
        return nil
    }
    
    func setRecordSize(id fileId: FileId, _ size: Int) {
        // create a fetch request based on the file ID
        let fileNamePredicate = NSPredicate(format: "name == %@", fileId.name)
        let uuidRequest = MetaData.fetchRequest()
        uuidRequest.predicate = fileNamePredicate
        var uuidResult: [MetaData] = []
        do {
            uuidResult = try context.fetch(uuidRequest)
        }
        catch {
            NSLog("failed to fetch uuid from core data , fileName: \(fileId.name), error: \(error.localizedDescription)")
            return
        }
        if uuidResult.isEmpty {
            NSLog("Record with name \(fileId.name) is not found. Size data won't be stored")
            return
        }

        guard let uuid = uuidResult[0].id else {
            NSLog("Failed to fetch correct UUID for record \(fileId.name)")
            return
        }
        
        // get meta data object corresponding to the file ID
        let uuidPredicate = NSPredicate(format: "id == %@", uuid.uuidString)
        let downloadMetadataRequest = DownloadMetaData.fetchRequest()
        downloadMetadataRequest.predicate = uuidPredicate
        var downloadMetaData: [DownloadMetaData] = []
        do {
            downloadMetaData = try context.fetch(downloadMetadataRequest)
        }
        catch {
            NSLog("failed to fetch download metadata from core data, filename \(fileId.name), error: \(error.localizedDescription)")
            return
        }
        if downloadMetaData.isEmpty {
            // TODO: it may be a valid case, consider creating a new entry
            NSLog("DownloadMetaData fetch result is empty. ATM we do not continue from this point. Name: \(fileId.name)")
            return
        }
        
        // set the meta data field size
        let downloadMetaDataEntry = downloadMetaData[0]
        
        downloadMetaDataEntry.rawFileSize = Int32(size)
        downloadMetaDataEntry.status = downloadStatusNotStarted
        
        // save the DB context
        saveContext()
    }
    
    func setRecordUrl(id fileId: FileId, url recordUrl: URL) {
        // fetch the metadata object, based on the file ID
        
        // set the metadata URL
        
        // save the context
    }
    
    func getRecordUrl(id fileId: FileId) -> URL? { return nil }
    func setRecordTime(id fileId: FileId, timestamp time: UInt32) {}
    
    // Metadata of download progress
    func setDownloadProgress(id fileId: FileId, _ progress: Float) {}
    func setDownloadDuration(id fileId: FileId, _ duration: Float) {}
    
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
                NSLog("Found an entry of an existing record. Checking the download metadata")
                for r in recordsMetadataList {
                    if r.name == f.name {
                        NSLog("requesting download metadata for \(r.name)")
                        let downloadMetaData = getDownloadMetaData(with: r.id!)
                        if let safeDownloadMetadata = downloadMetaData {
                            if safeDownloadMetadata.status == downloadStatusMetadataUnknown {
                                isMetadataFetchNeeded = true
                                isDataFetchNeeded = true
                            }
                            else if safeDownloadMetadata.status != downloadStatusCompleted {
                                isDataFetchNeeded = true
                                recordSize = Int(safeDownloadMetadata.rawFileSize)
                            }
                        }
                        else {
                            NSLog("warning: entry in DownloadMetaData doesn't exist for \(r.name)")
                            isMetadataFetchNeeded = true
                            isDataFetchNeeded = true
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
    func defineFtsJobs() -> [FtsJob] {
        return []
    }
    
    // Transcription-related methods
    func setRecordTranscription(with fileId: FileId, and text: String) {}
    func finalizeTranscription(with fileId: FileId) {}
    func getUntranscribedRecords() -> [FileId] { return [] }
    
    func deleteAllRecords() {
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
    
}
