// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2022, Roman Turkin
 */

import Foundation
import AVFoundation
import Speech

class SpeechRecognizer: ObservableObject
{
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
    static let shared = SpeechRecognizer()
    
    let recognizer: SFSpeechRecognizer?
    var transcript: String = ""
    
    init() {
        recognizer = SFSpeechRecognizer()
        Task(priority: .background) {
              do {
                  guard recognizer != nil else {
                      throw RecognizerError.nilRecognizer
                  }
                  guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                      throw RecognizerError.notAuthorizedToRecognize
                  }
              } catch {
                  speakError(error)
              }
          }
    }
    
    private func speak(_ message: String) {
        transcript = message
    }
    
    private func speakError(_ error: Error) {
        var errorMessage = ""
        if let error = error as? RecognizerError {
            errorMessage += error.message
        } else {
            errorMessage += error.localizedDescription
        }
        transcript = "<< \(errorMessage) >>"
    }
    
    func transcribe(record: Record, handler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void) {
        let request = SFSpeechURLRecognitionRequest(url: record.url!)
        request.shouldReportPartialResults = false
//        recognizer?.recognitionTask(with: request,
//                                    resultHandler: { (result, error) in
//            if let error = error {
//                print("recognition error: \(error)")
//            } else if let result = result {
//              print(result.bestTranscription.formattedString)
//            }
//        })
        print("starting recognition task")
        recognizer?.recognitionTask(with: request, resultHandler: handler)
    }
}

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
