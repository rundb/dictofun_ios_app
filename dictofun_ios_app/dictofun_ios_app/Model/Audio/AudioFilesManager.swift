// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import Foundation
import Logging

/// This class implements the storage functionality for files received from the Dictofun
class AudioFilesManager {
    private let fileManager: FileManager = .default
    private let recordsFolderPath: String = "records"
    
    enum FileSystemError: Error {
        case urlCreationError(String)
        case fileWriteError(String)
    }
    
    private var logger: Logger?
    
    init() {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            assert(false)
            logger?.error("failed to initialize the records' folder URL")
            return
        }
        let recordsFolderUrl = url.appendingPathComponent(recordsFolderPath)
        
        var isDir: ObjCBool = true
        if !fileManager.fileExists(atPath: recordsFolderUrl.relativePath, isDirectory: &isDir) {
            logger?.info("records' folder doesn't exist: creating one")
            do {
                try fileManager.createDirectory(at: recordsFolderUrl, withIntermediateDirectories: false)
                logger?.info("created records'folder")
            }
            catch let error {
                logger?.error("failed to create records' directory, error: \(error.localizedDescription)")
            }
        }
        else {
        }
    }
    
    func init_logger() {
        logger = Logger(label: "afm")
        logger?.logLevel = .debug
    }
    
    private func getRecordsFolderUrl() -> URL? {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else
        {
            return nil
        }
        return url
    }
    
    private func makeRecordURL(forFileNamed name: String) -> URL? {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else
        {
            return nil
        }
        let recordsFolderUrl = url.appendingPathComponent(recordsFolderPath)
        
        return recordsFolderUrl.appendingPathComponent(name, conformingTo: .url)
    }
    
    
    /// This function stores the record received from the Dictofun. It doesn't perform any manipulations with the data, so it implies
    /// that all decoding has been performed before entering this class. Wav header should also be applied before the call.
    func saveRecord(withRawWav data: Data, andFileName name: String) -> URL? {
        guard let url = makeRecordURL(forFileNamed: name) else {
            logger?.error("failed to create record url for name \(name)")
            return nil
        }
        
        let wavFile = createWaveFile(data: data)
        
        logger?.debug("creating path \(url.relativePath)")
        do {
            try wavFile.write(to: url)
            logger?.debug("saved a wav file to \(url.relativePath)")
        }
        catch {
            logger?.error("failed to write record's data")
            return nil
        }
        
        return url
    }
    
    func exists(url: URL?) -> Bool {
        guard let safeUrl = url else {
            return false
        }
        return fileManager.fileExists(atPath: safeUrl.relativePath)
    }
    
    func getRecordURL(withFileName fileName: String) -> URL? {
        let recordsUrl = makeRecordURL(forFileNamed: "")
        do {
            let items = try fileManager.contentsOfDirectory(at: recordsUrl!, includingPropertiesForKeys: nil)
            for item in items {
                if item.relativePath.contains(fileName) {
                    return item
                }
            }
        }
        catch {
        }
        guard let url = makeRecordURL(forFileNamed: fileName) else {
            return nil
        }
        return url
    }
    
    func removeRecord(_ url: URL) {
        do {
            try fileManager.removeItem(at: url)
        }
        catch let error {
            logger?.error("failed to remove record \(url.relativePath). Error: \(error.localizedDescription)")
        }
    }
    
    func removeAllRecords() {
        guard let recordsPath = makeRecordURL(forFileNamed: "") else {
            logger?.error("removeAllRecords - failed to get folder's URL")
            return
        }
        do {
            let items = try fileManager.contentsOfDirectory(atPath: recordsPath.relativePath)

            for item in items {
                let url = recordsPath.appendingPathComponent(item)
                do {
                    try fileManager.removeItem(at: url)
                }
                catch let error {
                    logger?.error("remove records: failed to remove record \(item), error: \(error.localizedDescription)")
                }
            }
            
        }
        catch let error {
            logger?.error("removeAllRecords(): \(error.localizedDescription)")
        }
    }
}
