//
//  TranscriptionJob.swift
//  dictofun_ios_app
//
//  Created by Roman on 07.11.23.
//

import Foundation

struct TranscriptionJob
{
    var uuid: UUID
    var fileUrl: URL
    var transcription: String?
    var isCompleted: Bool
}
