// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2022, Roman Turkin
 */
import SwiftUI

struct Record: Identifiable {
    let id: UUID
    let url: URL?
    let name: String
    let durationInSeconds: Int
    let transcription: String
    
    init(id: UUID = UUID(), url: URL, name: String, durationInSeconds: Int, transcription: String) {
        self.id = id
        self.name = name
        self.durationInSeconds = durationInSeconds
        self.transcription = transcription
        self.url = url
    }
}
