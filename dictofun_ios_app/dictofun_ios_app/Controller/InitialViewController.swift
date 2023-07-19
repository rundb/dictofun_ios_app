//
//  ViewController.swift
//  dictofun_ios_app
//
//  Created by Roman on 13.07.23.
//

import UIKit

class InitialViewController: UIViewController {
    @IBOutlet weak var unpairButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        print("Rotu: view will appear")
    }

//    @IBAction func unpairButtonPressed(_ sender: UIButton) {
//        print("unpair")
//    }
    @IBAction func unpairButtonPressed(_ sender: UIButton) {
    }
}

