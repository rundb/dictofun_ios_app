// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2022, Roman Turkin
 */
import SwiftUI

struct SideMenuView: View {
    var bluetooth: Bluetooth
    var recordsManager: RecordsManager
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    recordsManager.clearRecords()
                })
                {
                    Text("Delete records")
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 100)
            HStack {
                Button(action:
                {
                    let isPairedValue = bluetooth.userDefaults.value(forKey: "isPaired")
                    if isPairedValue != nil
                    {
                        bluetooth.userDefaults.removeObject(forKey: bluetooth.isPairedAlreadyKey)
                    }
                })
                {
                    Text("Reset pairing")
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 30)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 32/255, green: 32/255, blue: 32/255))
        .edgesIgnoringSafeArea(.all)
    }
}
