//
//  FtsJob.swift
//  dictofun_ios_app
//
//  Created by Roman on 18.09.23.
//

import Foundation

// This type describes which actions are pending for a particular record
struct FtsJob {
    var fileId: FileId
    var shouldFetchMetadata: Bool
    var shouldFetchData: Bool
}
