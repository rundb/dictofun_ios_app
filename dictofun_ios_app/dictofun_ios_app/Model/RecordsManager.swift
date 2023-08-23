// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import Foundation
import AVFoundation

/// This class implements the storage functionality for files received from the Dictofun
class RecordsManager: NSObject {
    private let fileManager: FileManager = .default
    private let recordsFolderPath: String = "records"
    var player: AVAudioPlayer? = nil
    
    enum FileSystemError: Error {
        case urlCreationError(String)
        case fileWriteError(String)
    }
    
    enum PlaybackError: Error {
        case failedToPlay
    }
    
    override init() {
        super.init()
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
        
        let wavFileHeader = createWaveHeader(data: data)
        let wavFile = wavFileHeader + data
        
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
    
    func getReadableFileName(with raw: String) -> String {
        let day = String(raw[raw.index(raw.startIndex, offsetBy: 0)...raw.index(raw.startIndex, offsetBy: 1)])
        let hour = String(raw[raw.index(raw.startIndex, offsetBy: 2)...raw.index(raw.startIndex, offsetBy: 3)])
        let minute = String(raw[raw.index(raw.startIndex, offsetBy: 4)...raw.index(raw.startIndex, offsetBy: 5)])
        let second = String(raw[raw.index(raw.startIndex, offsetBy: 6)...raw.index(raw.startIndex, offsetBy: 7)])
        
        return day + ", " + hour + ":" + minute + ":" + second
    }
    
    // TODO: replace sync call to duration with async one
    func getRecordsList() -> [Record] {
        guard let recordsPath = makeRecordURL(forFileNamed: "") else {
            NSLog("RecordsManager::getRecordsList - failed to get folder's URL")
            return []
        }
        do {
            let items = try fileManager.contentsOfDirectory(atPath: recordsPath.relativePath)
            var result: [Record] = []
            for item in items {
                let url = recordsPath.appendingPathComponent(item)
                let name = getReadableFileName(with: url.lastPathComponent)
                let audioAsset = AVURLAsset.init(url: url)
                let duration = audioAsset.duration
                let durationInSeconds = Int(CMTimeGetSeconds(duration))
//                let durationInSeconds = 2
                let record = Record(url: url, name: name, durationSeconds: durationInSeconds, progress: 0)
                result.append(record)
            }
            return result
        }
        catch let error {
            NSLog("RecordsManager::getRecordsList - failed to retrieve files from the folder, error: \(error.localizedDescription)")
        }
        return []
    }
    
    func playRecord(_ url: URL) -> Error? {
        NSLog("RecordsManager: playing \(url.relativePath)")
        if player == nil {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
                player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.wav.rawValue)
                guard let safePlayer = player else {
                    NSLog("RecordsManager: failed to play record \(url.relativePath). Failed to create a player")
                    return .some(PlaybackError.failedToPlay)
                }
                let playResult = safePlayer.play()
                if !playResult {
                    NSLog("RecordsManager: failed to play record \(url.relativePath). Playback error")
                    return .some(PlaybackError.failedToPlay)
                }
            }
            catch let error {
                NSLog("RecordsManager: exception during the playback. Error: \(error.localizedDescription)")
                return .some(PlaybackError.failedToPlay)
            }
            player?.delegate = self
        }
        else {
            return .some(PlaybackError.failedToPlay)
        }
        return nil
    }
    
    func removeRecord(_ url: URL) {
        do {
            try fileManager.removeItem(at: url)
        }
        catch let error {
            NSLog("RecordsManager: failed to remove record \(url.relativePath). Error: \(error.localizedDescription)")
        }
    }
}

extension RecordsManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        }
        catch let error {
            NSLog("RecordsManager: failed to deactivate av audio session. Error: \(error.localizedDescription)")
        }
    }
}
