// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2022, Roman Turkin
 */

import Foundation
import AVFoundation

class RecordsManager {
    static let shared = RecordsManager()
    let fileManager: FileManager = .default
    var player: AVAudioPlayer? = nil
    private let recordsFolder: String = "records"
    
    func generateFileName() -> String {
        let today = Date()
        let hours   = String(format: "%2d", Calendar.current.component(.hour, from: today))
        let minutes = String(format: "%02d", Calendar.current.component(.minute, from: today))
        let seconds = String(format: "%02d", Calendar.current.component(.second, from: today))
        let day = String(format: "%02d", Calendar.current.component(.day, from: today))
        let month = String(format: "%02d", Calendar.current.component(.month, from: today))
        let year = String(Calendar.current.component(.year, from: today))
        let fileName = "\(year).\(month).\(day)-\(hours):\(minutes):\(seconds).wav"
        return fileName
    }
    
    func makeURL(forFileNamed fileName: String) -> URL? {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else
        {
            return nil
        }
        let recordsFolderUrl = url.appendingPathComponent(recordsFolder)
        var isDir: ObjCBool = false
        if !fileManager.fileExists(atPath: recordsFolderUrl.path, isDirectory: &isDir)
        {
            print("creating records folder")
            do
            {
                try fileManager.createDirectory(at: recordsFolderUrl, withIntermediateDirectories: true)
            }
            catch {
                print("failed to create the records folder")
            }
        }
        return url.appendingPathComponent(recordsFolder).appendingPathComponent(fileName)
    }
    
    func openRecordFile() -> URL?
    {
        guard let url = makeURL(forFileNamed: generateFileName()) else {
            return nil
        }
        if fileManager.fileExists(atPath: url.absoluteString)
        {
            return nil
        }
        return url
    }
    
    func getRecords() -> [Record] {
        var records: [Record] = []
        do {
            guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            else { return []}
            let recordsUrl = url.appendingPathComponent(recordsFolder)
            let items = try fileManager.contentsOfDirectory(at: recordsUrl, includingPropertiesForKeys: nil)
            for item in items {
                records.append(Record(url: item, name: item.lastPathComponent, durationInSeconds: 0, transcription: ""))
            }
            return records
        }
        catch let error {
            print("get records error \(error)")
        }
        return records
    }
}
