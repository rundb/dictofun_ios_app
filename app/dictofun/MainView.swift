// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2022, Roman Turkin
 */

import SwiftUI
import CoreBluetooth

struct MainView: View {
    var bluetooth = Bluetooth.shared
    var recordsManager: RecordsManager
    
    @State var presented: Bool = false
    @State var list = [Bluetooth.Device]()
    @State var isConnected: Bool = Bluetooth.shared.current != nil { didSet { if isConnected { presented.toggle() } } }
    @State var dictofunPeripheral: CBPeripheral? = nil
    @State var isPaired: Bool = Bluetooth.shared.isPaired
    
    var body: some View {
        if !isPaired
        {
            VStack{
                Text("Dictofun")
                Spacer()
                Text("Welcome to dictofun")
                Spacer()
                NavigationView() {
                    ZStack{
                        Color.cyan.edgesIgnoringSafeArea(.all)
                        NavigationLink (destination: PairingView(bluetooth: bluetooth, presented: $presented, list: $list, isConnected: $isConnected,
                             dictofunPeripheral: $dictofunPeripheral)){
                            Text("Start pairing")
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
                .onAppear { bluetooth.delegate = self }
            }
        }
        else
        {
            VStack{
                Text("Dictofun")
                Spacer()
                Text("Application automatically in the background attempts to download the records from the dictofun device")
                    .font(.system(size: 12))
                Spacer()
                // // TODO: move this to a menu of settings
                Button("reset internal pairing info") {
                    let isPairedValue = bluetooth.userDefaults.value(forKey: "isPaired")
                    if isPairedValue != nil
                    {
                        print(isPairedValue!)
                        bluetooth.userDefaults.removeObject(forKey: bluetooth.isPairedAlreadyKey)
                    }
                }
                Spacer()
                Spacer()
                NavigationView() {
                    ZStack{
                        Color.cyan.edgesIgnoringSafeArea(.all)
                        NavigationLink (destination: RecordsView(recordsManager: recordsManager, records: recordsManager.getRecords())){
                            Text("List records")
                        }.buttonStyle(PlainButtonStyle())
                    }
                    
                }
                Spacer()
                Button("remove all records") {
                    recordsManager.clearRecords()
                }
            }
        }
    }
}

extension MainView: BluetoothProtocol {
    func value(data: Data) {
        
    }
    
    func state(state: Bluetooth.State) {
        switch state {
        case .unknown: print("◦ .unknown")
        case .resetting: print("◦ .resetting")
        case .unsupported: print("◦ .unsupported")
        case .unauthorized: print("◦ bluetooth disabled, enable it in settings")
        case .poweredOff: print("◦ turn on bluetooth")
        case .poweredOn: print("◦ everything is ok")
        case .error: print("• error")
        case .connected:
            print("◦ connected to \(bluetooth.current?.name ?? "")")
            isConnected = true
        case .disconnected:
            print("◦ disconnected")
            isConnected = false
        }
        isPaired = bluetooth.isPaired
    }
    
    func list(list: [Bluetooth.Device]) { self.list = list }
    
}
