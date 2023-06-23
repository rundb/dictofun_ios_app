//
//  BlePairingView.swift
//  dictofun
//
//  Created by Roman on 16.05.23.
//

import SwiftUI

struct BlePairingView: View {
    var bleController: BleControlProtocol?
    @Binding var bleContext: BleContext
    @State private var updatesCount: Int = 0
    
    var body: some View {
        VStack {
            Text("Welcome to Dictofun")
                .font(.largeTitle)
            Text("This application will take you through pairing process. Press \"start scanning\" to " +
                 "start scanning for a Dictofun close by the phone. Press \"stop scanning\" in order to stop " +
                 "process of scanning")
            .padding()
            .multilineTextAlignment(.center)
            
            Text("Conn. st:" +
                 ($bleContext.wrappedValue.bleState == .connected ? "connected," : "disconnected,") + 
                 ($bleContext.wrappedValue.isPaired ? "paired" : "not paired"))
            Button(action: {
                bleController?.startScan()
                NSLog("ble:: start scanning")
                updatesCount += 1
            })
            {
                Text("start scanning")
            }
            .padding()
            .background(($bleContext.wrappedValue.bleState == .ready) ? .cyan : .gray)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled($bleContext.wrappedValue.bleState != .ready)
            
            Button(action: {
                bleController?.stopScan()
                NSLog("ble:: stop scanning")
                updatesCount += 1
            })
            {
                Text("stop scanning")
            }
            .padding()
            .background(($bleContext.wrappedValue.bleState == .scanning) ? .cyan : .gray)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled($bleContext.wrappedValue.bleState != .scanning)
            
            Button(action: {
                bleController?.connect()
                NSLog("connecting to discovered device")
                updatesCount += 1
            })
            {
                Text("connect")
            }
            .padding()
            .background(($bleContext.wrappedValue.discoveredDevicesCount == 1) ? .cyan : .gray)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled($bleContext.wrappedValue.discoveredDevicesCount != 1)
            
            Button(action: {
                let pairingResult = bleController?.pair()
                NSLog("attempting pairing " + (pairingResult! ? "ok" : "failed"))
                updatesCount += 1
            })
            {
                Text("pair")
            }
            .padding()
            .background($bleContext.wrappedValue.bleState == .connected && !$bleContext.wrappedValue.isPaired ? .cyan : .gray)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Button(action: {
                bleController?.unpair()
                NSLog("unpaired")
                updatesCount += 1
            })
            {
                Text("unpair")
            }
            .padding()
            .background($bleContext.wrappedValue.bleState == .connected && $bleContext.wrappedValue.isPaired ? .cyan : .gray)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(!($bleContext.wrappedValue.bleState == .connected && $bleContext.wrappedValue.isPaired))
            
            // This is a workaround to enforce the view to update on the buttons' presses
            Text(String(updatesCount)).hidden()
        }
    }
}

struct BlePairingView_Previews: PreviewProvider {
    @State static var bleContext: BleContext = BleContext(bleState: .idle, isPaired: false)
    static var previews: some View {
        BlePairingView(
            bleController: BleControllerMock(),
            bleContext: $bleContext
        )
    }
}
