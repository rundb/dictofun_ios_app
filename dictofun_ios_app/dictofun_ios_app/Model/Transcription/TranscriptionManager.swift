//
//  TranscriptionManager.swift
//  dictofun_ios_app
//
//  Created by Roman on 07.11.23.
//

import Foundation
import AVFoundation
import Speech

class TranscriptionManager
{
    let recognizer: SFSpeechRecognizer?
    
    enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable
        
        var message: String {
            switch self {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .notPermittedToRecord: return "Not permitted to record audio"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            }
        }
    }
    
    enum CompletionError {
        case recognitionError, otherError
    }
    init() {
        NSLog("recognizer - before constructor")
        recognizer = SFSpeechRecognizer()
        NSLog("recognizer - after constructor")
        Task(priority: .background) {
            do {
                guard recognizer != nil else {
                    throw RecognizerError.nilRecognizer
                }
                SFSpeechRecognizer.requestAuthorization{ authStatus in
                    if authStatus != .authorized {
                        NSLog("failed to receive speech recognition authorization")
                    }
                }
            } catch {
                NSLog("Speech recognizer error: \(error)")
            }
            
        }
    }
    
    func requestTranscription(url: URL, callback: @escaping (CompletionError?, String?) -> Void) {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        recognizer?.recognitionTask(with: request, resultHandler: {(result, error) in
            if result != nil {
                // successful recognition
                let transcription = result?.bestTranscription.formattedString
                if !transcription!.isEmpty {
                    callback(nil, transcription)
                    NSLog("successful transcription, text \(transcription!)")
                }
                else {
                    callback(.recognitionError, nil)
                    NSLog("recognition error")
                }
            }
            else if error != nil{
                callback(.otherError, nil)
                NSLog("other error in recognition process (\(error?.localizedDescription)")
            }
            else
            {
                callback(.otherError, nil)
                NSLog("never supposed to happen")
            }
        })
    }
}
