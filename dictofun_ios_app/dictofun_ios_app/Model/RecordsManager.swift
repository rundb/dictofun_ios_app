//
//  RecordsManager.swift
//  dictofun_ios_app
//
//  Created by Roman on 21.07.23.
//

import Foundation
import AVFoundation

/// This class implements the storage functionality for files received from the Dictofun
class RecordsManager {
    private let fileManager: FileManager = .default
    private let recordsFolderPath: String = "records"
    var player: AVAudioPlayer? = nil
    
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
        guard let url = makeRecordURL(forFileNamed: name+".wav") else {
            return .some(FileSystemError.urlCreationError("URL could not be generated"))
        }
        
        let wavFileHeader = createWaveHeader(data: data)
        let wavFile = wavFileHeader + data
        
        print(wavFile.count)
        print(data.count)
        for i in stride(from: 0, through: 0x1000, by: 16) {
            print(String(format: "(%x) %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x",
                         i, wavFile[i + 0], wavFile[i + 1], wavFile[i + 2], wavFile[i + 3], wavFile[i + 4], wavFile[i + 5], wavFile[i + 6], wavFile[i + 7],
                            wavFile[i + 8], wavFile[i + 9], wavFile[i + 10], wavFile[i + 11], wavFile[i + 12], wavFile[i + 13], wavFile[i + 14], wavFile[i + 15]))
        }
        
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
        guard let url = makeRecordURL(forFileNamed: fileName+".wav") else {
            return nil
        }
        return url
    }
    
    private func intToByteArray(_ i: Int32) -> [UInt8] {
          return [
            //little endian
            UInt8(truncatingIfNeeded: (i      ) & 0xff),
            UInt8(truncatingIfNeeded: (i >>  8) & 0xff),
            UInt8(truncatingIfNeeded: (i >> 16) & 0xff),
            UInt8(truncatingIfNeeded: (i >> 24) & 0xff)
           ]
     }
    
    private func shortToByteArray(_ i: Int16) -> [UInt8] {
           return [
               //little endian
               UInt8(truncatingIfNeeded: (i      ) & 0xff),
               UInt8(truncatingIfNeeded: (i >>  8) & 0xff)
           ]
     }
    
    private func createWaveHeader(data: Data) -> Data {
         let sampleRate:Int32 = 16000
         let chunkSize:Int32 = 36 + Int32(data.count)
         let subChunkSize:Int32 = 16
         let format:Int16 = 1
         let channels:Int16 = 1
         let bitsPerSample:Int16 = 16
         let byteRate:Int32 = sampleRate * Int32(channels * bitsPerSample / 8)
         let blockAlign: Int16 = channels * bitsPerSample / 8
         let dataSize:Int32 = Int32(data.count)

         var header = Data([])

         header.append([UInt8]("RIFF".utf8), count: 4)
         header.append(intToByteArray(chunkSize), count: 4)

         //WAVE
         header.append([UInt8]("WAVE".utf8), count: 4)

         //FMT
         header.append([UInt8]("fmt ".utf8), count: 4)

         header.append(intToByteArray(subChunkSize), count: 4)
         header.append(shortToByteArray(format), count: 2)
         header.append(shortToByteArray(channels), count: 2)
         header.append(intToByteArray(sampleRate), count: 4)
         header.append(intToByteArray(byteRate), count: 4)
         header.append(shortToByteArray(blockAlign), count: 2)
         header.append(shortToByteArray(bitsPerSample), count: 2)

         header.append([UInt8]("data".utf8), count: 4)
         header.append(intToByteArray(dataSize), count: 4)

         return header
    }
    
    func getRecordsList() -> [String] {
        guard let recordsPath = makeRecordURL(forFileNamed: "") else {
            NSLog("RecordsManager::getRecordsList - failed to get folder's URL")
            return []
        }
        do {
            let items = try fileManager.contentsOfDirectory(atPath: recordsPath.relativePath)
            var result: [String] = []
            for item in items {
                result.append(item)
            }
            return result
        }
        catch let error {
            NSLog("RecordsManager::getRecordsList - failed to retrieve files from the folder, error: \(error.localizedDescription)")
        }
        return []
    }
}
