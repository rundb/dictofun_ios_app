// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2022, Roman Turkin
 */
import SwiftUI

struct Record: Identifiable {
    var id: String
    let url: URL?
    let name: String
    let durationInSeconds: Int
    let transcription: String
    let transcriptionURL: URL?
    
    init(url: URL, name: String, durationInSeconds: Int, transcription: String, transcriptionURL: URL) {
        // Using hashable string Name to sort the records in the chronological order
        self.id = name
        self.name = name
        self.durationInSeconds = durationInSeconds
        self.transcription = transcription
        self.url = url
        self.transcriptionURL = transcriptionURL
    }
    
    
    
    
}
