//
//  AppDelegate.swift
//  dictofun_ios_app
//
//  Created by Roman on 13.07.23.
//

import UIKit

var bluetoothManager = BluetoothManager()
var printLogger = PrintLogger()
var recordsManager = RecordsManager()
var fileTransferService = FileTransferService(with: bluetoothManager, andRecordsManager:  recordsManager)

func getBluetoothManager() -> BluetoothManager {
    return bluetoothManager
}

func getFileTransferService() -> FileTransferService {
    return fileTransferService
}

func getRecordsManager() -> RecordsManager {
    return recordsManager
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        bluetoothManager.logger = printLogger
        // Override point for customization after application launch.
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

}

