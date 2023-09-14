//
//  AudioPlayer.swift
//  dictofun_ios_app
//
//  Created by Roman on 31.08.23.
//

import Foundation
import AVFoundation

class AudioPlayer: NSObject {
    var player: AVAudioPlayer? = nil
    
    enum PlaybackError: Error {
        case failedToPlay
    }
    
    func playRecord(_ url: URL) -> Error? {
        NSLog("AudioPlayer: playing \(url.relativePath)")
        if player == nil {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
                player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.wav.rawValue)
                guard let safePlayer = player else {
                    NSLog("RecordsManager: failed to play record \(url.relativePath). Failed to create a player")
                    return .some(PlaybackError.failedToPlay)
                }
                let playResult = safePlayer.play()
                if !playResult {
                    NSLog("RecordsManager: failed to play record \(url.relativePath). Playback error")
                    return .some(PlaybackError.failedToPlay)
                }
            }
            catch let error {
                NSLog("RecordsManager: exception during the playback. Error: \(error.localizedDescription)")
                return .some(PlaybackError.failedToPlay)
            }
            player?.delegate = self
        }
        else {
            return .some(PlaybackError.failedToPlay)
        }
        return nil
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        }
        catch let error {
            NSLog("RecordsManager: failed to deactivate av audio session. Error: \(error.localizedDescription)")
        }
    }
}
