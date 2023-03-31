// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import SwiftUI
import CoreBluetooth

struct FtsTestsView: View {
    var bluetooth = Bluetooth.shared
    @Binding var isConnected: Bool
    @Binding var dictofunPeripheral: CBPeripheral?
    var body: some View {
        VStack{
            Text("Connection status: \(isConnected ? "connected" : "disconnected")")
            Button("get list"){
                
            }
            .buttonStyle(.borderedProminent)
            Button("get status"){
                
            }
            .buttonStyle(.borderedProminent)
            Button("get last file info"){
                
            }
            .buttonStyle(.borderedProminent)
            Button("get last data"){
                
            }
            .buttonStyle(.borderedProminent)
            Text("FTS Status")
            Text("Log:")
            Spacer()
        }
        .navigationTitle("FTS Tests")
    }
}
