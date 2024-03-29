// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import UIKit
import CoreData
import Logging
import GoogleCloudLogging

var bluetoothManager = BluetoothManager()
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
        fileTransferService.ftsEventNotificationDelegate = ftsManager
        ftsManager.launchTranscriptions()
        
        LoggingSystem.bootstrap { MultiplexLogHandler([GoogleCloudLogHandler(label: $0), StreamLogHandler.standardOutput(label: $0)]) }

        do {
            try GoogleCloudLogHandler.setup(serviceAccountCredentials: Bundle.main.url(forResource: "dictofun-ios-logging-token", withExtension: "json")!, clientId: UIDevice.current.identifierForVendor)
            GoogleCloudLogHandler.uploadInterval = 60
            GoogleCloudLogHandler.logger.logLevel = .warning
            
            recordsManager.init_logger()
            bluetoothManager.init_logger()
            fileTransferService.init_logger()
            ftsManager.init_logger()
            audioFilesManager.init_logger()
        } catch {
            NSLog("Failed to initialize GoogleCloudLogHandler")
        }

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

