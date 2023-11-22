// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import Foundation
import AVFoundation

protocol PlaybackEndDelegate {
    func playbackFinished()
}

class AudioPlayer: NSObject {
    var player: AVAudioPlayer? = nil
    
    enum PlaybackError: Error {
        case failedToPlay
        case failedToPause
    }
    
    var playbackEndDelegate: PlaybackEndDelegate?
    
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
                    NSLog("RecordsManager: failed to play record \(url.relativePath). Playback error (\(playResult.description)")
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
    
//    func pause() -> Error? {
//        NSLog("pause the playback")
//        guard let safePlayer = player else {
//            NSLog("audio player is nil. error")
//            return .some(PlaybackError.failedToPause)
//        }
//        safePlayer.pause()
//        return nil
//    }
    
//    func resume() -> Error? {
//        NSLog("resuming playback")
//        guard let safePlayer = player else {
//            NSLog("audio player is nil. error")
//            return .some(PlaybackError.failedToPlay)
//        }
//        let result = safePlayer.play()
//        if !result {
//            NSLog("failed to resume record. Error: \(result.description)")
//            return .some(PlaybackError.failedToPlay)
//        }
//        return nil
//    }
    
    func stopPlayingRecord() {
        NSLog("stopping the playback")
        guard let safePlayer = player else {
            NSLog("audio player is nil. doing nothing")
            return
        }
        safePlayer.stop()
        player = nil
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
        if playbackEndDelegate != nil {
            playbackEndDelegate?.playbackFinished()
        }
    }
}
