//
//  AudioAlerting.swift
//  IEYE
//
//  Created by Itay Haphiloni on 19/02/2026.
//
import Foundation

public protocol AudioAlerting: AnyObject {
    func playWarning()
    func playAlarm()
    func stop()
}

