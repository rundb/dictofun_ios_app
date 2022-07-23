// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2022, Roman Turkin
 */

import Foundation
import AVFoundation
import Speech

class RecordsManager {
    static let shared = RecordsManager()
    let fileManager: FileManager = .default
    var player: AVAudioPlayer? = nil
    var recognizer: SpeechRecognizer = SpeechRecognizer.shared
    private let recordsFolder: String = "records"
    private let transcriptionsFolder: String = "transcript"
    private var recordUnderProcessing: Record? = nil
    
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
        
        let transcriptionsFolderUrl = url.appendingPathComponent(transcriptionsFolder)
        isDir = false
        if !fileManager.fileExists(atPath: transcriptionsFolderUrl.path, isDirectory: &isDir)
        {
            print("creating transcriptions folder")
            do
            {
                try fileManager.createDirectory(at: transcriptionsFolderUrl, withIntermediateDirectories: true)
            }
            catch {
                print("failed to create the transcriptions folder")
            }
        }

        return url.appendingPathComponent(recordsFolder).appendingPathComponent(fileName)
    }
    
    func makeTranscriptionURL(forFileNamed fileName: String) -> URL? {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else
        {
            return nil
        }
        var isDir: ObjCBool = false
        let transcriptionsFolderUrl = url.appendingPathComponent(transcriptionsFolder)
        isDir = false
        if !fileManager.fileExists(atPath: transcriptionsFolderUrl.path, isDirectory: &isDir)
        {
            print("creating transcriptions folder")
            do
            {
                try fileManager.createDirectory(at: transcriptionsFolderUrl, withIntermediateDirectories: true)
            }
            catch {
                print("failed to create the transcriptions folder")
            }
        }

        return url.appendingPathComponent(transcriptionsFolder).appendingPathComponent(fileName)
    }
    
    func getTranscription(transcriptionUrl: URL) -> String? {
        do {
            let transcript = try String(contentsOf: transcriptionUrl, encoding: .utf8)
            return transcript
        }
        catch {
            print("no transcription found for \(transcriptionUrl.lastPathComponent)")
            return nil
        }
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
            let transcriptionsUrl = url.appendingPathComponent(transcriptionsFolder)
            let items = try fileManager.contentsOfDirectory(at: recordsUrl, includingPropertiesForKeys: nil)
            for item in items {
                let asset = AVURLAsset(url: item)
                let audioDuration = asset.duration
                let audioDurationSeconds = Int(CMTimeGetSeconds(audioDuration))
                let name = item.deletingPathExtension().lastPathComponent
                let transcriptName = name + ".txt"
                let transcriptionUrl = transcriptionsUrl.appendingPathComponent(transcriptName)
                let transcriptTry = getTranscription(transcriptionUrl: transcriptionUrl)
                var transcript = ""
                if transcriptTry == nil {
                    // Perform an extra finalization call, if transcript doesn't exist.
                    print("performing an extra transcription")
                    finalizeRecord(recordURL: item)
                }
                else
                {
                    transcript = transcriptTry!
                }
                records.append(Record(url: item, name: item.lastPathComponent,
                                      durationInSeconds: audioDurationSeconds, transcription: transcript, transcriptionURL: transcriptionUrl))
            }
            return records
        }
        catch let error {
            print("get records error \(error)")
        }
        return records
    }
    
    func transcriptionCallback(speechRecognitionResult: SFSpeechRecognitionResult?, error: Error?) {
        var transcription: String = ""
        if let error = error {
            print("transcription error: \(error)")
        }
        else
        {
            transcription = (speechRecognitionResult?.bestTranscription.formattedString)!
            print("transcription: \(transcription)")
        }
        do {
            try transcription.write(to: (recordUnderProcessing?.transcriptionURL)!, atomically: false, encoding: .utf8)
        }
        catch {
            print("failed to store transcription \(recordUnderProcessing?.name)")
        }
        recordUnderProcessing = nil
    }
    
    func finalizeRecord(recordURL: URL)
    {
        print("start record finalization")
        let transcriptName = recordURL.deletingPathExtension().lastPathComponent + ".txt"
        let recordName = recordURL.lastPathComponent
        let transcriptURL = makeTranscriptionURL(forFileNamed: transcriptName)
        var record: Record = Record(url: recordURL, name: recordName, durationInSeconds: 0, transcription: "", transcriptionURL: transcriptURL!)
        // TODO: implement processing queue. For now just a dummy wait in case if previous transcription is not done (effectively a
        //       blocking single-element queue for now).
        if recordUnderProcessing == nil {
            recordUnderProcessing = record
        }
        else
        {
            print("record under processing is not nil, recognition will be performed at another time")
//            sleep(10)
//            recordUnderProcessing = record
            return;
        }
        recognizer.transcribe(record: record, handler: transcriptionCallback)

    }
    
    func clearRecords() {
        let records = getRecords()
        var isRecordUrlRemovalSucceeded: Bool = false
        for record in records
        {
            do {
                try fileManager.removeItem(at: record.url!)
                isRecordUrlRemovalSucceeded = true
                try fileManager.removeItem(at: record.transcriptionURL!)
            }
            catch let _ {
                if (!isRecordUrlRemovalSucceeded)
                {
                    print("failed to remove file \(record.name)")
                }
                else
                {
                    print("failed to remove transcript \(record.transcriptionURL?.lastPathComponent)")
                }
            }
            
        }
    }
}
