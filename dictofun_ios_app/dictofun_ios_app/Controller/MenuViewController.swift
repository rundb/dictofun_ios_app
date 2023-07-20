//
//  MenuViewController.swift
//  dictofun_ios_app
//
//  Created by Roman on 14.07.23.
//

import UIKit

class MenuViewController: UIViewController {
    var fts: FileTransferService?

    override func viewDidLoad() {
        super.viewDidLoad()

        fts = getFileTransferService()
    }

    
    @IBAction func menuUnpairButtonPressed(_ sender: UIButton) {
        getBluetoothManager().unpair()
        self.navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction func testFts1ButtonPressed(_ sender: UIButton) {
//        print("Fts 1 button pressed: get files' list")
//        let filesListResult = fts?.requestFilesList()
//        guard filesListResult == nil else {
//            print("Files List request has failed")
//            return
//        }
        print("Fts 1 button pressed: get file system status")
        let fsStatusResult = fts?.requestFileSystemStatus()
        guard fsStatusResult == nil else {
            print("File System status request has failed")
            return
        }
    }
    @IBAction func testFts2ButtonPressed(_ sender: UIButton) {
        print("Fts 2 button pressed: test file info request")
        let filesIds = fts?.getFileIds()
        if (filesIds?.count ?? 0) > 0 {
            let count = filesIds!.count
            let lastId = filesIds![0]
            let error = fts?.requestFileInfo(with: lastId)
            if error != nil {
                print("FTS file info request has failed")
            }
        }
    }
    
    @IBAction func testFts3ButtonPressed(_ sender: UIButton) {
        print("Fts 3 button pressed: test file data request")
        let filesIds = fts?.getFileIds()
        if (filesIds?.count ?? 0) > 0 {
            let count = filesIds!.count
            let lastId = filesIds![0]
            let error = fts?.requestFileData(with: lastId)
            if error != nil {
                print("FTS file data request has failed")
            }
        }
    }
}
