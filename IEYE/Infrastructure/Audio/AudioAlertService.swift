import Foundation
import AVFoundation

final class AudioAlertService: AudioAlerting {
    private var player: AVAudioPlayer?
    
    init() {
        setupAudioSession()
        preparePlayer()
    }
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Allows audio to play even on silent mode
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("AudioSession error: \(error)")
        }
    }
    
    private func preparePlayer() {
        // Ensure this matches your filename exactly
        guard let url = Bundle.main.url(forResource: "warning-alarm", withExtension: "wav") else {
            print("Audio file warning-alarm.wav not found")
            return
        }
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1 // Loop the alarm until stopped
            player?.prepareToPlay()
        } catch {
            print("AVAudioPlayer init error: \(error)")
        }
    }
    
    func playWarning() {
        // You could play a shorter beep here, but for now we'll play the alarm
        play()
    }
    
    func playAlarm() {
        play()
    }
    
    func stop() {
        player?.stop()
        player?.currentTime = 0 // Reset to start
    }
    
    private func play() {
        if player?.isPlaying == false {
            player?.play()
        }
    }
}
