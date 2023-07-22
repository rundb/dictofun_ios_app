//
//  RecordsManager.swift
//  dictofun_ios_app
//
//  Created by Roman on 21.07.23.
//

import Foundation

/// This class implements the storage functionality for files received from the Dictofun
class RecordsManager {
    private let fileManager: FileManager = .default
    private let recordsFolderPath: String = "records"
    
    enum FileSystemError: Error {
        case urlCreationError(String)
        case fileWriteError(String)
    }
    
    init() {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            assert(false)
            NSLog("RecordsManager: failed to initialize the records' folder URL")
            return
        }
        let recordsFolderUrl = url.appendingPathComponent(recordsFolderPath)
        
        var isDir: ObjCBool = true
        if !fileManager.fileExists(atPath: recordsFolderUrl.absoluteString, isDirectory: &isDir) {
            NSLog("RecordsManager: records' folder doesn't exist: creating one")
            do {
                try fileManager.createDirectory(at: recordsFolderUrl, withIntermediateDirectories: true)
            }
            catch {
                NSLog("RecordsManager: failed to create records' directory")
            }
        }
    }
    
    private func makeRecordURL(forFileNamed name: String) -> URL? {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else
        {
            return nil
        }
        let recordsFolderUrl = url.appendingPathComponent(recordsFolderPath)
        return recordsFolderUrl.appending(path: name)
    }
    
    
    /// This function stores the record received from the Dictofun. It doesn't perform any manipulations with the data, so it implies
    /// that all decoding has been performed before entering this class. Wav header should also be applied before the call.
    func saveRecord(withRawWav data: Data, andFileName name: String) -> Error? {
        guard let url = makeRecordURL(forFileNamed: name) else {
            return .some(FileSystemError.urlCreationError("URL could not be generated"))
        }
        
        NSLog("Records Manager: creating path \(url.absoluteString)")
        do {
            try data.write(to: url)
        }
        catch {
            NSLog("RecordsManager: failed to write record's data")
            return .some(FileSystemError.fileWriteError("Data couldn't be written"))
        }
        
        return nil
    }
    
    func getRecordsList() -> [String] {
        guard let recordsPath = makeRecordURL(forFileNamed: "") else {
            NSLog("RecordsManager::getRecordsList - failed to get folder's URL")
            return []
        }
        do {
            let items = try fileManager.contentsOfDirectory(atPath: recordsPath.absoluteString)
            var result: [String] = []
            for item in items {
                result.append(item)
            }
            return result
        }
        catch {
            NSLog("RecordsManager::getRecordsList - failed to retrieve files from the folder")
        }
        return []
    }
}
