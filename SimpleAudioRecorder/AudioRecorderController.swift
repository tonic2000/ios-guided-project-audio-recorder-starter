//
//  ViewController.swift
//  AudioRecorder
//
//  Created by Paul Solt on 10/1/19.
//  Copyright © 2019 Lambda, Inc. All rights reserved.
//

import UIKit
import AVFoundation

class AudioRecorderController: UIViewController {
    
    //MARK:-IBOutlets
    
    @IBOutlet var playButton: UIButton!
    @IBOutlet var recordButton: UIButton!
    @IBOutlet var timeElapsedLabel: UILabel! {
        didSet {
            timeElapsedLabel.font = UIFont.monospacedDigitSystemFont(ofSize: timeElapsedLabel.font.pointSize,
                                                                    weight: .regular)
        }
    }
    
    @IBOutlet var timeRemainingLabel: UILabel! {
        didSet {

            timeRemainingLabel.font = UIFont.monospacedDigitSystemFont(ofSize: timeRemainingLabel.font.pointSize,
                                                                       weight: .regular)
        }
    }
    
    @IBOutlet var timeSlider: UISlider!
    @IBOutlet var audioVisualizer: AudioVisualizer!
    
    //MARK:- Properties
    
    // We can only play DRM-free music ( can't use Apple Music )
    var audioPlayer: AVAudioPlayer? {
        didSet {
            audioPlayer?.delegate = self
            
        }
    }
    
    private lazy var timeIntervalFormatter: DateComponentsFormatter = {
        // NOTE: DateComponentFormatter is good for minutes/hours/seconds
        // DateComponentsFormatter is not good for milliseconds, use DateFormatter instead)
        
        let formatting = DateComponentsFormatter()
        formatting.unitsStyle = .positional // 00:00  mm:ss
        formatting.zeroFormattingBehavior = .pad
        formatting.allowedUnits = [.minute, .second]
        return formatting
    }()
    
    
    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Use a font that won't jump around as values change
      try? prepareAudioSession()
        loadAudio()
        updateViews()
    }
    
    
    private func updateViews() {
        playButton.isSelected = isPlaying
        recordButton.isSelected = isRecording
        
        let eslapsedTime = audioPlayer?.currentTime ?? 0
        let duration = audioPlayer?.duration ?? 0
        
        timeElapsedLabel.text = timeIntervalFormatter.string(from: eslapsedTime)
        timeRemainingLabel.text = timeIntervalFormatter.string(from: duration)
        
        timeSlider.value = Float(eslapsedTime)
        timeSlider.minimumValue = 0
        timeSlider.maximumValue = Float(duration)
    }
    
    private var timer: Timer?
    // MARK: - Timer
    
    
    func startTimer() {
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.030, repeats: true) { [weak self] (_) in
            guard let self = self else { return }
            
            self.updateViews()
            
//            if let audioRecorder = self.audioRecorder,
//                self.isRecording == true {
//
//                audioRecorder.updateMeters()
//                self.audioVisualizer.addValue(decibelValue: audioRecorder.averagePower(forChannel: 0))
//
//            }
//
            if let audioPlayer = self.audioPlayer,
                self.isPlaying == true {
            
                audioPlayer.updateMeters()
                self.audioVisualizer.addValue(decibelValue: audioPlayer.averagePower(forChannel: 0))
            }
        }
    }
    
    func cancelTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    
    
    // MARK: - Playback
    
    var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
    }
    

    func loadAudio() {
        let songURL = Bundle.main.url(forResource: "piano", withExtension: "mp3")!
        
        audioPlayer = try? AVAudioPlayer(contentsOf: songURL)
        audioPlayer?.isMeteringEnabled = true 
    }
    
    
    func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try session.setActive(true, options: []) // can fail if on a phone call, for instance
    }
    
    
    func play() {
        audioPlayer?.play()
        startTimer()
        updateViews()
    }
    
    func pause() {
        audioPlayer?.pause()
        cancelTimer()
        updateViews()
    }
    
    
    // MARK: - Recording
    var audioRecorder: AVAudioRecorder?
    var recordingURL: URL? 
    var isRecording: Bool {
        audioRecorder?.isRecording ?? false
    }
    
    func createNewRecordingURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let name = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: .withInternetDateTime)
        let file = documents.appendingPathComponent(name, isDirectory: false).appendingPathExtension("caf")
        
        print("recording URL: \(file)")
        
        return file
    }
    
    
    func requestPermissionOrStartRecording() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                guard granted == true else {
                    print("We need microphone access")
                    return
                }
                
                print("Recording permission has been granted!")
//                 NOTE: Invite the user to tap record again, since we just interrupted them, and they may not have been ready to record
            }
        case .denied:
            print("Microphone access has been blocked.")
            
            let alertController = UIAlertController(title: "Microphone Access Denied", message: "Please allow this app to access your Microphone.", preferredStyle: .alert)
            
            alertController.addAction(UIAlertAction(title: "Open Settings", style: .default) { (_) in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            })
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
            
            present(alertController, animated: true, completion: nil)
        case .granted:
            startRecording()
        @unknown default:
            break
        }
    }
    
    
    func startRecording() {
       let recordingURL = createNewRecordingURL()
        // Setup the AVAudioRecorder and record
        
        // 44.1 KHz = FM radio quality
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        
        self.recordingURL = recordingURL
        audioRecorder = try? AVAudioRecorder(url: recordingURL, format: audioFormat)
       //FIXME: error logic
        audioRecorder?.delegate = self
        audioRecorder?.record()
        updateViews()
        
        
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        updateViews()
    }
    
    // MARK: - Actions
    
    @IBAction func togglePlayback(_ sender: Any) {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    @IBAction func updateCurrentTime(_ sender: UISlider) {
        if isPlaying {
              pause()
          }
          audioPlayer?.currentTime = TimeInterval(timeSlider.value)
          updateViews()
    }
    
    @IBAction func toggleRecording(_ sender: Any) {
        if isRecording {
            stopRecording()
        } else {
            requestPermissionOrStartRecording()
        }
    }
}

extension AudioRecorderController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        updateViews()
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("Audio Player Decode Error: \(error)")
        }
        updateViews()
    }
}
extension AudioRecorderController: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {

        // set up the player the recording
        if let recordingURL = recordingURL {
            audioPlayer = try? AVAudioPlayer(contentsOf: recordingURL) //FIXME: do/catch
            
        }
            
        updateViews()
    }
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Audio Recorder Error: \(error)")
        }
    }
}
