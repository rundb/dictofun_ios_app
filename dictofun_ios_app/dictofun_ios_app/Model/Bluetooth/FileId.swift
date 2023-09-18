//
//  FileId.swift
//  dictofun_ios_app
//
//  Created by Roman on 18.09.23.
//

import Foundation

// File is an 16-byte long ID
struct FileId {
    let value: Data
    init(value: Data) {
        self.value = value
        assert(value.count == 16)
    }
    
    var name: String {
        if let validAsciiString = String(data: value, encoding: .ascii) {
            return validAsciiString
        }
        return "unknownunknown"
    }
    
    static func getIdByName(with name: String) -> FileId {
        guard let data = name.data(using: .ascii) else {
            NSLog("FileId: failed to convert ascii string to bytes")
            return FileId(value: Data([]))
        }
        return FileId(value: data)
    }
}

enum FileType {
    case wavData
    case adpcmData
}
