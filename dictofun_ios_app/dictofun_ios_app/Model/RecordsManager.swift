// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

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
        if !fileManager.fileExists(atPath: recordsFolderUrl.relativePath, isDirectory: &isDir) {
            NSLog("RecordsManager: records' folder doesn't exist: creating one")
            do {
                try fileManager.createDirectory(at: recordsFolderUrl, withIntermediateDirectories: false)
                NSLog("RecordsManager: created records'folder")
            }
            catch let error {
                NSLog("RecordsManager: failed to create records' directory, error: \(error.localizedDescription)")
            }
        }
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
        
        return recordsFolderUrl.appending(path: name)
    }
    
    
    /// This function stores the record received from the Dictofun. It doesn't perform any manipulations with the data, so it implies
    /// that all decoding has been performed before entering this class. Wav header should also be applied before the call.
    func saveRecord(withRawWav data: Data, andFileName name: String) -> Error? {
        guard let url = makeRecordURL(forFileNamed: name) else {
            return .some(FileSystemError.urlCreationError("URL could not be generated"))
        }
        
        let wavFile = createWaveFile(data: data)
        
        NSLog("Records Manager: creating path \(url.relativePath)")
        do {
            try wavFile.write(to: url)
            NSLog("Records Manager: saved a wav file to \(url.relativePath)")
        }
        catch {
            NSLog("RecordsManager: failed to write record's data")
            return .some(FileSystemError.fileWriteError("RecordsManager:Data couldn't be written"))
        }
        
        return nil
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
    
    
    static private func splitDateToComponents(with raw: String) -> [String] {
        var result: [String] = []
        result.append(String(raw[raw.index(raw.startIndex, offsetBy: 4)...raw.index(raw.startIndex, offsetBy: 5)]))
        result.append(String(raw[raw.index(raw.startIndex, offsetBy: 6)...raw.index(raw.startIndex, offsetBy: 7)]))
        result.append(String(raw[raw.index(raw.startIndex, offsetBy: 8)...raw.index(raw.startIndex, offsetBy: 9)]))
        result.append(String(raw[raw.index(raw.startIndex, offsetBy: 10)...raw.index(raw.startIndex, offsetBy: 11)]))
        result.append(String(raw[raw.index(raw.startIndex, offsetBy: 12)...raw.index(raw.startIndex, offsetBy: 13)]))
        result.append(String(raw[raw.index(raw.startIndex, offsetBy: 14)...raw.index(raw.startIndex, offsetBy: 15)]))
        return result
    }
    
    static func getReadableFileName(with raw: String) -> String {
        let tokens = splitDateToComponents(with: raw)
        return tokens[0] + "." + tokens[1] + "." + tokens[2] + ", " + tokens[3] + ":" + tokens[4] + ":" + tokens[5]
    }
    
    static func getReadableRecordDate(with raw: String) -> String {
        let tokens = splitDateToComponents(with: raw)
        return tokens[0] + "." + tokens[1] + "." + tokens[2]
    }
                      
    static func getReadableRecordTime(with raw: String) -> String {
        let tokens = splitDateToComponents(with: raw)
        return tokens[3] + ":" + tokens[4] + ":" + tokens[5]
    }
    
    // TODO: replace sync call to duration with async one
    func getRecordsList(excludeEmpty: Bool = false) -> [Record] {
        guard let recordsPath = makeRecordURL(forFileNamed: "") else {
            NSLog("RecordsManager::getRecordsList - failed to get folder's URL")
            return []
        }
        do {
            let items = try fileManager.contentsOfDirectory(atPath: recordsPath.relativePath)
            var result: [Record] = []
            for item in items {
                let url = recordsPath.appendingPathComponent(item)
                let name = url.lastPathComponent
                
                // TODO: replace this with appropriate duration calculation. Currently just an assumption that 1 second of record takes 16 kbytes
                var durationInSeconds = 0
                
                do {
                    let recordFileAttr = try fileManager.attributesOfItem(atPath: url.relativePath)
                    let fileSize = recordFileAttr[FileAttributeKey.size] as! Int
                    durationInSeconds = fileSize / (16384)
                }
                catch let error {
                    NSLog("failed to fetch record size: \(error.localizedDescription)")
                }
                
                var fileSize = 0
                if excludeEmpty {
                    do {
                        let fileAttr = try fileManager.attributesOfItem(atPath: url.relativePath)
                        fileSize = fileAttr[FileAttributeKey.size] as! Int
                        if fileSize < FileTransferService.minimalFileSize {
                            NSLog("RecordsManager, discovered file smaller than minimal: \(fileSize)")
                        }
                    }
                    catch let error {
                        NSLog("RecordsManager: exception while attempting to extract file size (\(error.localizedDescription))")
                    }
                }
                
                let record = Record(url: url, name: name, durationSeconds: durationInSeconds, progress: 0)
                if !excludeEmpty {
                    result.append(record)
                }
                else if fileSize >= FileTransferService.minimalFileSize
                {
                    result.append(record)
                }
            }
            result.sort(by: {
                $0.name > $1.name
            })
            
            return result
        }
        catch let error {
            NSLog("RecordsManager::getRecordsList - failed to retrieve files from the folder, error: \(error.localizedDescription)")
        }
        return []
    }
    
    func removeRecord(_ url: URL) {
        do {
            try fileManager.removeItem(at: url)
        }
        catch let error {
            NSLog("RecordsManager: failed to remove record \(url.relativePath). Error: \(error.localizedDescription)")
        }
    }
    
    func removeAllRecords() {
        guard let recordsPath = makeRecordURL(forFileNamed: "") else {
            NSLog("RecordsManager::removeAllRecords - failed to get folder's URL")
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
                    NSLog("remove records: failed to remove error \(item), error: \(error.localizedDescription)")
                }
            }
        }
        catch let error {
            NSLog("removeAllRecords(): error \(error.localizedDescription)")
        }
    }
}
