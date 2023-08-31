//
//  FTSManager.swift
//  dictofun_ios_app
//
//  Created by Roman on 31.08.23.
//

import Foundation

/*
 This module connects FileTransferService to the application
 */

class FTSManager {
    
    let fts: FileTransferService
    let rm: RecordsManager
    
    init(ftsService fts: FileTransferService, recordsManager rm: RecordsManager) {
        self.fts = fts
        self.rm = rm
    }
}

// TODO: move the detection logic itself to the records' manager, leaving only a connection at this point
extension FTSManager: NewFilesDetectionDelegate {
    func detectNewFiles(with fileIds: [FileId]) -> [FileId] {
        NSLog("warning: detectNewFiles should be moved to another abstraction level")
        let existingRecords = rm.getRecordsList()
        var existingFileNames: [String] = []
        for r in existingRecords {
            existingFileNames.append(r.name)
        }
        
        var fileNames: [String] = []
        for f in fileIds {
            fileNames.append(f.name)
        }
        
        let newFileNames = findNewFiles(new: fileNames, existing: existingFileNames)
        var newFileIds: [FileId] = []
        for name in newFileNames {
            newFileIds.append(getFileIdByName(with: name, and: fileIds)!)
        }
        return newFileIds
    }
    
    private func findNewFiles(new lhs: [String], existing rhs: [String]) -> [String] {
        NSLog("warning: findNewFiles should be moved to another abstraction level")
        var rhsSet: Set<String> = []
        for name in rhs {
            rhsSet.insert(name)
        }
        var result: [String] = []
        for name in lhs {
            if !rhsSet.contains(name) {
                result.append(name)
            }
        }
        return result
    }
    
    private func getFileIdByName(with name: String, and fileIds: [FileId]) -> FileId? {
        NSLog("warning: getFileIdByName should be moved to another abstraction level")
        for f in fileIds {
            if f.name == name {
                return f
            }
        }
        return nil
    }

}


//private func detectNewRecords(with files: [FileId]) -> [FileId] {
//    let existingRecords = recordsManager.getRecordsList()
//    var existingFileNames: [String] = []
//    for r in existingRecords {
//        existingFileNames.append(r.name)
//    }
//
//    var fileNames: [String] = []
//    for f in files {
//        fileNames.append(f.name)
//    }
//
//    let newFileNames = findNewFiles(new: fileNames, existing: existingFileNames)
//    var newFileIds: [FileId] = []
//    for name in newFileNames {
//        newFileIds.append(getFileIdByName(with: name)!)
//    }
//    return newFileIds
//}
