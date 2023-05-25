//
//  StartScreenView.swift
//  dictofun
//
//  Created by Roman on 16.05.23.
//

import SwiftUI

struct StartScreenView: View {
    var bleController: BleControlProtocol
    @Binding var bleContext : BleContext
    var fts: FileTransferServiceProtocol?
    
    init(bleController: BleControlProtocol, bleContext: Binding<BleContext>) {
        self.bleController = bleController
        self._bleContext = bleContext

        fts = FileTransferServiceMock()
    }
    
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink(destination: BlePairingView(bleController: bleController, bleContext: $bleContext)) {
                    Text("Pairing View")
                }
                .padding()
                .background(.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                NavigationLink(destination: RecordsView()) {
                    Text("records view")
                }
                .padding()
                .background(.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                NavigationLink(destination: BleDevelopmentView(
                    bleController: bleController,
                    bleContext: bleContext,
                    fts: fts!)
                )
                {
                    Text("ble dev view")
                }
                .padding()
                .background(.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Text(BluetoothController.bleStateToString($bleContext.wrappedValue.bleState))
            }
        }
    }
}

struct StartScreenView_Previews: PreviewProvider {
    @State static var bleContext: BleContext = BleContext(bleState: .idle, isPaired: false)
    static var previews: some View {
        StartScreenView(bleController: BleControllerMock(), bleContext: $bleContext)
    }
}
