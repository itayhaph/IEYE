//
//  AudioAlertService.swift
//  IEYE
//
//  Created by Itay Haphiloni on 19/02/2026.
//
import Foundation
import AVFoundation
import AudioToolbox

public final class AudioAlertService: AudioAlerting {

    private var alarmPlayer: AVAudioPlayer?
    private var warningPlayer: AVAudioPlayer?

    public init() {
        alarmPlayer = makePlayer(resource: "alarm", ext: "wav", loops: true)
        warningPlayer = makePlayer(resource: "warning", ext: "wav", loops: false)
    }

    public func playWarning() {
        stop()
        if let p = warningPlayer {
            p.currentTime = 0
            p.play()
        } else {
            AudioServicesPlaySystemSound(1103)
        }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    public func playAlarm() {
        stop()
        if let p = alarmPlayer {
            p.play()
        } else {
            AudioServicesPlaySystemSound(1005)
        }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    public func stop() {
        alarmPlayer?.stop()
        alarmPlayer?.currentTime = 0
        warningPlayer?.stop()
        warningPlayer?.currentTime = 0
    }

    private func makePlayer(resource: String, ext: String, loops: Bool) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else { return nil }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = loops ? -1 : 0
            p.prepareToPlay()
            return p
        } catch {
            print("Audio init failed \(resource).\(ext): \(error)")
            return nil
        }
    }
}

