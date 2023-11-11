// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import UIKit
import CoreData

var bluetoothManager = BluetoothManager()
var printLogger = PrintLogger()
var audioFilesManager = AudioFilesManager()
var recordsManager = RecordsManager()
var transcriptionManager = TranscriptionManager()
var fileTransferService = FileTransferService(with: bluetoothManager)
var ftsManager = FTSManager(ftsService: fileTransferService, audioFilesManager: audioFilesManager, recordsManager: recordsManager, transcriptionManager: transcriptionManager)
var audioPlayer = AudioPlayer()

func getBluetoothManager() -> BluetoothManager {
    return bluetoothManager
}

func getFileTransferService() -> FileTransferService {
    return fileTransferService
}

func getFtsManager() -> FTSManager {
    return ftsManager
}

func getRecordsManager() -> RecordsManager {
    return recordsManager
}

func getAudioFilesManager() -> AudioFilesManager {
    return audioFilesManager
}

func getAudioPlayer() -> AudioPlayer {
    return audioPlayer
}

func getTranscriptionManager() -> TranscriptionManager {
    return transcriptionManager
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//        bluetoothManager.logger = printLogger
        fileTransferService.ftsEventNotificationDelegate = ftsManager
        ftsManager.launchTranscriptions()
        
        // Override point for customization after application launch.
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        NSLog("app has entered background")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        NSLog("app will enter foreground")
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DataModel")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}

