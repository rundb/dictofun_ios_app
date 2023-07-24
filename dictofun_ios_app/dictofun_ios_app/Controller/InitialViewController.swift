// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import UIKit

class InitialViewController: UIViewController {
    
    @IBOutlet weak var basicDescriptionLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        basicDescriptionLabel.textColor = .black
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if getBluetoothManager().paired {
            NSLog("InitialView: dictofun is paired, continue to menu view")
            self.performSegue(withIdentifier: K.initialToRecordsSegueName, sender: self)
        }
        else {
            NSLog("InitialView: dictofun is not yet paired, stay at intro menu view")
        }
    }
    
    @IBAction func getStartedButtonPressed(_ sender: UIButton) {
        if !getBluetoothManager().paired {
            self.performSegue(withIdentifier: K.connectionViewSegueName, sender: self)
        }
        else {
            NSLog("InitialView: dictofun is paired, continue to menu view")
            self.performSegue(withIdentifier: K.initialToRecordsSegueName, sender: self)
        }
    }
}

