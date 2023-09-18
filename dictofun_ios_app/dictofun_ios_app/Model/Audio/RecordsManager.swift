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
        
        // get meta data object corresponding to the file ID
        
        // set the meta data field size
        
        // save the DB context
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
    
    // Methods used prior to records' download
    func detectNewRecords(with fileIds: [FileId]) -> [FtsJob] {
        let recordsMetadataList = getRecords()
        if !recordsMetadataList.isEmpty {
            NSLog("existing records: ")
        }
        var existingFileIds: [FileId] = []
        for r in recordsMetadataList {
            NSLog("\(r.id?.uuidString), \(r.name)")
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
            }
            else {
                NSLog("Found an entry of an existing record. Checking the download metadata")
                for r in recordsMetadataList {
                    if r.name == f.name {
                        NSLog("requesting download metadata for \(r.name)")
                        let downloadMetaData = getDownloadMetaData(with: r.id!)
                        if let safeDownloadMetadata = downloadMetaData {
                            NSLog("Download metadata: \(safeDownloadMetadata.status)")
                        }
                        else {
                            NSLog("No download metadata found for the record \(r.name)")
                        }
                    }
                }
            }
        }
        return ftsJobs
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
