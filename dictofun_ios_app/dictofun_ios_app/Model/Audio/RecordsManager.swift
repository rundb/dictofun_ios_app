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
        let metaData = MetaData(context: context)
        let downloadMetaData = DownloadMetaData(context: context)
        let transcription = Transcription(context: context)
        let newUUID = UUID()
        metaData.id = newUUID
        downloadMetaData.id = newUUID
        downloadMetaData.status = downloadStatusNotStarted
        transcription.id = newUUID
        transcription.isCompleted = false
        metaData.name = fileId.name
        
        saveContext()
    }
    
    
    func getRecords() -> [UUID] {
        let request = MetaData.fetchRequest()
        do {
            let recordsEntries = try context.fetch(request)
            var result: [UUID] = []
            for r in recordsEntries {
                result.append(r.id!)
            }
            return result
        }
        catch {
            NSLog("Failed to fetch db context: \(error)")
            return []
        }
    }
    
    func setRecordSize(id fileId: FileId, _ size: Int) {}
    func setRecordUrl(id fileId: FileId, url recordUrl: URL) {}
    func getRecordUrl(id fileId: FileId) -> URL? { return nil }
    func setRecordTime(id fileId: FileId, timestamp time: UInt32) {}
    
    // Metadata of download progress
    func setDownloadProgress(id fileId: FileId, _ progress: Float) {}
    func setDownloadDuration(id fileId: FileId, _ duration: Float) {}
    
    // Methods used prior to records' download
    func detectNewRecords(with fileIds: [FileId]) -> [FileId] { return [] }
    
    // Transcription-related methods
    func setRecordTranscription(with fileId: FileId, and text: String) {}
    func finalizeTranscription(with fileId: FileId) {}
    func getUntranscribedRecords() -> [FileId] { return [] }
    
}
