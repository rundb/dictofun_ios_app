// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2022, Roman Turkin
 */

import SwiftUI
import CoreBluetooth
import ComposableArchitecture

struct MainView: View {
    var bluetooth = Bluetooth.shared
    var recordsManager: RecordsManager
    var recognizer: SpeechRecognizer
    var fts: FileTransferService
    
    @State var presented: Bool = false
    @State var list = [Bluetooth.Device]()
    @State var isConnected: Bool = Bluetooth.shared.current != nil { didSet { if isConnected { presented.toggle() } } }
    @State var dictofunPeripheral: CBPeripheral? = nil
    @State var isPaired: Bool = Bluetooth.shared.isPaired
    @State var showSideMenu = false
    
    var defaultView: some View {
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
    
    var defaultViewAfterPairing: some View {
        NavigationView() {
            VStack {
                Color.green.edgesIgnoringSafeArea(.all)
                NavigationLink(destination: OldRecordsView(recordsManager: recordsManager, records: recordsManager.getRecords())){
                    Text("List records")
                }
                .buttonStyle(.borderedProminent)
                
                NavigationLink(destination: FtsTestsView(bluetooth: bluetooth, isConnected: $isConnected, dictofunPeripheral: $dictofunPeripheral)) {
                    Text("FTS Tests")
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                Color.green.edgesIgnoringSafeArea(.all)
            }
        }.background(Color.green)
    }
    
    var body: some View {
        let drag = DragGesture()
            .onEnded {_ in
                withAnimation {
                    self.showSideMenu = false
                }
            }
        
        return NavigationView {
            GeometryReader{ geometry in
                ZStack(alignment: .leading) {
                    if !isPaired
                    {
                        defaultView
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    else
                    {
                        defaultViewAfterPairing
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(x: self.showSideMenu ? geometry.size.width/2 : 0)
                            .disabled(self.showSideMenu)
                    }

                    if self.showSideMenu {
                        SideMenuView(bluetooth: bluetooth, recordsManager: recordsManager)
                            .frame(width: geometry.size.width/2)
                            .transition(.move(edge: .leading))
                    }
                }
                .gesture(drag)
            }
            .navigationBarTitle("Dictofun", displayMode: .inline)
            .navigationBarItems(leading: (
                Button(action: {
                    withAnimation {
                        self.showSideMenu.toggle()
                    }
                }) {
                    Image(systemName: "line.horizontal.3")
                        .imageScale(.large)
                }
            ))
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
            NSLog("◦ connected to \(bluetooth.current?.name ?? "")")
            isConnected = true
        case .disconnected:
            NSLog("◦ disconnected")
            isConnected = false
        }
        isPaired = bluetooth.isPaired
    }
    
    func list(list: [Bluetooth.Device]) { self.list = list }
    
}
