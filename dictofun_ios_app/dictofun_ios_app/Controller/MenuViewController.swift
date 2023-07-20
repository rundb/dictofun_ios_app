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
        print("Fts 1 button pressed")
    }
    
}
