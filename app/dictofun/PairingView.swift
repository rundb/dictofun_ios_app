// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2022, Roman Turkin
 */


import SwiftUI
import CoreBluetooth

struct PairingView: View {
    var bluetooth: Bluetooth
    @Binding var presented: Bool
    @Binding var list: [Bluetooth.Device]
    @Binding var isConnected: Bool
    @Binding var dictofunPeripheral: CBPeripheral?
    
    @Environment (\.presentationMode) var presentation
    
    var body: some View {
        VStack
        {
            Text("Scanning Bluetooth devices, looking for the Dictofun")
            Spacer()
            List(list) { peripheral in
                if peripheral.peripheral.name!.starts(with: "d")
                {
                    Button(action: {
                        bluetooth.connect(peripheral.peripheral)
                        
                    })
                    {
                        HStack {
                            Text(peripheral.peripheral.name ?? "")
                            Spacer()
                        }
                        HStack {
                            if !isConnected
                            {
                                Text(peripheral.uuid).font(.system(size: 10)).foregroundColor(.gray)
                            }
                            else
                            {
                                Text(peripheral.uuid).font(.system(size: 10)).foregroundColor(.cyan)
                            }
                            Spacer()
                        }
                    }
                }
            }.listStyle(InsetGroupedListStyle())
            .onAppear {
                bluetooth.startScanning()
            }
            .onDisappear {
                bluetooth.stopScanning()
            }
            .padding(.vertical, 0)
            Spacer()
            if isConnected
            {
                Button("pair") {
                    bluetooth.pair()
                    self.presentation.wrappedValue.dismiss()
                }
                Spacer()
            }
        }
    }
}
