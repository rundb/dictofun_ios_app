//
//  StartScreenView.swift
//  dictofun
//
//  Created by Roman on 16.05.23.
//

import SwiftUI

struct StartScreenView: View {
    var bleController: BleControlProtocol?
    var bleContext: BleContext
    
    init() {
        bleController = BleControllerMock()
        bleContext = BleContext(bleState: .idle, isPaired: false)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink(destination: BlePairingView(bleController: bleController, bleContext: bleContext)) {
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
                
                NavigationLink(destination: BleDevelopmentView()) {
                    Text("ble dev view")
                }
                .padding()
                .background(.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }
}

struct StartScreenView_Previews: PreviewProvider {
    static var previews: some View {
        StartScreenView()
    }
}
