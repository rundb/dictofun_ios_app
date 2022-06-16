// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2022, Roman Turkin
 */

import SwiftUI
import AVFoundation

let sampleUrl: URL? = nil
let sampleRecords: [Record] = [
    Record(url: sampleUrl!, name: "rec 1", durationInSeconds: 30, transcription: "sample transcription 1"),
    Record(url: sampleUrl!, name: "rec 2", durationInSeconds: 65, transcription: "sample transcription 2"),
]

struct RecordsView: View {
    var bluetooth: Bluetooth
    var records: [Record]
    var body: some View {
        List {
            ForEach(records) { record in
                VStack {
                    HStack {
                        Text(record.name)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Button {
                            // TODO: add playback of the record
                            playbackRecord(url: record.url!)
                        } label: {
                            Image(systemName: "play.fill")
                        }
                        Spacer()
                        Text("\(record.durationInSeconds)")
                    }
                }
//                Button(record.name) {
//
//                }
            }
        }
    }
    
    func playbackRecord(url: URL)
    {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            bluetooth.player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.wav.rawValue)
            guard let player = bluetooth.player else { return }
            player.play()
        }
        catch let error {
            print("playback error \(error)");
        }
    }
}

//struct RecordsView_Previews: PreviewProvider {
//    static var previews: some View {
//        RecordsView(records: sampleRecords)
//    }
//}
