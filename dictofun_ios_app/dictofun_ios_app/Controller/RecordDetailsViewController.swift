// SPDX-License-Identifier:  Apache-2.0
/*
 * Copyright (c) 2023, Roman Turkin
 */

import UIKit

protocol TranscriptionUpdateDelegate {
    func saveTranscriptionText(with id: UUID, and transcription: String)
}

class RecordDetailsViewController: UIViewController {
    
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var saveTranscriptionButton: UIButton!
    @IBOutlet weak var recordDateLabel: UILabel!
    @IBOutlet weak var recordTimeLabel: UILabel!
    @IBOutlet weak var playbackPositionLabel: UILabel!
    @IBOutlet weak var playbackProgressBar: UIProgressView!
    @IBOutlet weak var transcriptionText: UITextView!
    @IBOutlet weak var playbackDurationLabel: UILabel!
    
    var recordViewData: RecordViewData?
    var isPlaying = false
    var isPaused = false
    var wasEdited = false
    let audioPlayer: AudioPlayer = getAudioPlayer()
    var recordsTableReloadDelegate: TableReloadDelegate?
    var transcriptionUpdateDelegate: TranscriptionUpdateDelegate?
    
    override func viewDidLoad() {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MMM/yyyy"
        recordDateLabel.text = "\(formatter.string(from: recordViewData!.creationDate!))"
        recordDateLabel.textColor = .darkGray
        
        formatter.dateFormat = "  HH:mm:ss"
        recordTimeLabel.text = "\( formatter.string(from: recordViewData!.creationDate!) )"
        recordTimeLabel.textColor = .darkGray
        
        if let duration = recordViewData?.durationSeconds {
            playbackPositionLabel.text = "00:00"
            playbackPositionLabel.isHidden = true
            playbackDurationLabel.text = String(format: "%02d:%02d", duration / 60, duration % 60)
        }
        else {
            playbackPositionLabel.text = "--:--"
            playbackDurationLabel.text = "--:--"
        }
        
        stopButton.isHidden = true
        
        if let transcription = recordViewData?.transcription {
            transcriptionText.text = transcription
            transcriptionText.textColor = .darkGray
        }
        else {
            transcriptionText.text = "---"
        }
        
        playbackProgressBar.progress = 0
        
        if let url = recordViewData?.url {
            let fm = FileManager.default
            if !fm.fileExists(atPath: url.relativePath) {
                NSLog("File does not exist")
                playPauseButton.isEnabled = false
            }
        }
        else {
            playPauseButton.isEnabled = false
        }
        transcriptionText.delegate = self
        wasEdited = false
        saveTranscriptionButton.isEnabled = wasEdited
        saveTranscriptionButton.backgroundColor = .gray
        saveTranscriptionButton.titleLabel?.textColor = .white
    }
    
    
    fileprivate func disableButtonsAndPlayback() {
        playPauseButton.isEnabled = false
        stopButton.isHidden = true
        isPaused = false
        isPlaying = false
        audioPlayer.stopPlayingRecord()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        recordsTableReloadDelegate?.reloadTable()
        // add playback stop at this point
    }
    
    @IBAction func onPlayPauseButtonPress(_ sender: Any) {
        if (!isPlaying)
        {
            if (isPaused) {
//                let resumeResult = audioPlayer.resume()
//                if resumeResult != nil {
//                    NSLog("resume operation failed (\(resumeResult.debugDescription)")
//                    disableButtonsAndPlayback()
//                    return
//                }
//                isPaused = false
//                isPlaying = true
            }
            if let url = recordViewData?.url {
                let result = audioPlayer.playRecord(url)
                if result != nil {
                    NSLog("play operation failed (\(result.debugDescription)")
                    disableButtonsAndPlayback()
                    return
                }
                else {
                    isPlaying = true
                    stopButton.isEnabled = true
                    stopButton.isHidden = false
                    playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                    audioPlayer.playbackEndDelegate = self
                    playPauseButton.isEnabled = false
                }
            }
        }
        else {
//            let pauseResult = audioPlayer.pause()
//            if pauseResult != nil {
//                NSLog("pause operation failed (\(pauseResult.debugDescription)")
//                disableButtonsAndPlayback()
//                return
//            }
//            isPlaying = false
//            isPaused = true
//            
//            playPauseButton.setImage(UIImage(systemName: "arrowtriangle.right.fill"), for: .normal)
        }
        
    }
    @IBAction func onStopButtonPress(_ sender: Any) {
        if isPlaying {
            isPlaying = false
            stopButton.isHidden = true
            audioPlayer.stopPlayingRecord()
            playPauseButton.setImage(UIImage(systemName: "arrowtriangle.right.fill"), for: .normal)
            playPauseButton.isEnabled = true
        }
    }
    @IBAction func onSaveTranscriptionPress(_ sender: UIButton) {
        if wasEdited {
            guard let delegate = transcriptionUpdateDelegate, let id = recordViewData?.uuid else
            {
                return
            }
            delegate.saveTranscriptionText(with: id, and: transcriptionText.text)
            wasEdited = false
            saveTranscriptionButton.isEnabled = wasEdited
            saveTranscriptionButton.backgroundColor = .gray
            view.endEditing(false)
        }
    }
    
    @IBAction func onDeleteButtonPress(_ sender: Any) {
        if isPlaying {
            isPlaying = false
            audioPlayer.stopPlayingRecord()
            playPauseButton.isEnabled = false
        }
        if let uuid = recordViewData?.uuid {
            getRecordsManager().deleteRecord(with: uuid)
        }
        if let delegate = recordsTableReloadDelegate {
            delegate.reloadTable()
        }
        self.dismiss(animated: true)
    
    }
}

extension RecordDetailsViewController: PlaybackEndDelegate {
    func playbackFinished() {
        NSLog("playback finished callback")
        isPlaying = false
        stopButton.isHidden = true
        playPauseButton.isEnabled = true
        playPauseButton.setImage(UIImage(systemName: "arrowtriangle.right.fill"), for: .normal)
    }
}

extension RecordDetailsViewController: UITextViewDelegate
{
    func textViewDidBeginEditing(_ textView: UITextView) {
        wasEdited = true
        saveTranscriptionButton.isEnabled = true
        saveTranscriptionButton.backgroundColor = .blue
    }
}
