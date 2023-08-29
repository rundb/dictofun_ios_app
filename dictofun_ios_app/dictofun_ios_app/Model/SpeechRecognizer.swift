// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
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
        recognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en"))
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
    
    func transcribe(recordUrl: URL, handler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void) {
        let request = SFSpeechURLRecognitionRequest(url: recordUrl)
        request.shouldReportPartialResults = false
        NSLog("starting recognition task (file \(recordUrl.relativePath)")
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
