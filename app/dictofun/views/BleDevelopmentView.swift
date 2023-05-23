//
//  BleDevelopmentView.swift
//  dictofun
//
//  Created by Roman on 16.05.23.
//

import SwiftUI

/**
 This view contains buttons that should be used to develop a BLE FTS controller functions.
 In particular, this display should be capable of launching FTS functions and showing the result of their execution
 */
struct BleDevelopmentView: View {
    var bleController: BleControlProtocol
    var bleContext: BleContext
    var fts: FileTransferServiceProtocol
    var latestResponse: String = ""
    var body: some View {
        VStack {
            Text("FTS Dev View")
                .font(.largeTitle)
                .padding()
            
            Text("Conn status:\t" + (bleContext.bleState == .connected ? "connected" : "disconnected"))
            Text("Pairing status:\t\t" + (bleContext.isPaired ? "paired" : "not-paired"))
            Button(action: {}) {
                Text("get files list")
            }
            .padding()
            .background(.cyan)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Button(action: {}) {
                Text("get last file size")
            }
            .padding()
            .background(.cyan)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Button(action: {}) {
                Text("get last file data")
            }
            .padding()
            .background(.cyan)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Button(action: {}) {
                Text("get FS Stats")
            }
            .padding()
            .background(.cyan)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Spacer()
            Text("Latest FTS response:")
            Text(latestResponse)
        }
    }
}

struct BleDevelopmentView_Previews: PreviewProvider {
    static var previews: some View {
        BleDevelopmentView(bleController: BleControllerMock(),
                           bleContext: BleContext(bleState: .idle, isPaired: true),
                           fts: FileTransferServiceMock()
        )
    }
}
