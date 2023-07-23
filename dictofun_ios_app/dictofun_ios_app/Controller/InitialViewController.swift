// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import UIKit

class InitialViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if getBluetoothManager().paired {
            NSLog("InitialView: dictofun is paired, continue to menu view")
            self.performSegue(withIdentifier: K.initialToMenuSegueName, sender: self)
        }
        else {
            NSLog("InitialView: dictofun is not yet paired, stay at intro menu view")
        }
    }

    @IBAction func unpairButtonPressed(_ sender: UIButton) {
        getBluetoothManager().unpair()
    }
    
    @IBAction func getStartedButtonPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: K.connectionViewSegueName, sender: self)
    }
}

