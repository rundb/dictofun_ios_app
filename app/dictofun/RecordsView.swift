// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2022, Roman Turkin
 */

import SwiftUI
import AVFoundation

let sampleUrl: URL? = nil
let sampleRecords: [Record] = [
    Record(url: sampleUrl!, name: "rec 1", durationInSeconds: 30, transcription: "sample transcription 1", transcriptionURL: sampleUrl!),
    Record(url: sampleUrl!, name: "rec 2", durationInSeconds: 65, transcription: "sample transcription 2", transcriptionURL: sampleUrl!),
]

struct RecordsView: View {
    var recordsManager: RecordsManager
    @State var records: [Record]
    var body: some View {
        HStack
        {
            List {
                ForEach(records) { record in
                    VStack {
                        HStack {
                            Text(record.name)
                            Spacer()
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            HStack {
                                Button {
                                    playbackRecord(url: record.url!)
                                } label: {
                                    Image(systemName: "play.fill")
                                }
                                Spacer()
                                Text(String(format: "%02d:%02d", record.durationInSeconds/60, record.durationInSeconds%60))
                            }
                            Spacer()
                            Text(record.transcription).font(.system(size: 10))
                        }
                    }
    //                Button(record.name) {
    //
    //                }
                }
            }
            .onAppear()
            {
                records = recordsManager.getRecords()
            }
        }
    }
    
    func playbackRecord(url: URL)
    {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            recordsManager.player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.wav.rawValue)
            guard let player = recordsManager.player else { return }
            player.play()
        }
        catch let error {
            print("playback error \(error)");
        }
    }
}
