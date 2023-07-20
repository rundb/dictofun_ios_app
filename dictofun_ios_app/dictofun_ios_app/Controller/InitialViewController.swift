//
//  ViewController.swift
//  dictofun_ios_app
//
//  Created by Roman on 13.07.23.
//

import UIKit

class InitialViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if getBluetoothManager().paired {
            print("dictofun is paired, continue to menu view")
            self.performSegue(withIdentifier: K.initialToMenuSegueName, sender: self)
        }
        else {
            print("dictofun is not yet paired, stay at intro menu view")
        }
    }

    @IBAction func unpairButtonPressed(_ sender: UIButton) {
        getBluetoothManager().unpair()
    }
    
    @IBAction func getStartedButtonPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: K.connectionViewSegueName, sender: self)
    }
}

