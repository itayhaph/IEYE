//
//  DrowsinessState.swift
//  IEYE
//
//  Created by Itay Haphiloni on 19/02/2026.
//

import Foundation

public enum AlertLevel: Equatable {
    case none
    case warning
    case alarm
    case noFace
}

public struct DrowsinessState: Equatable {
    public var alert: AlertLevel
    public var perclos: Double          // 0..1
    public var isCalibrated: Bool
    public var calibrationProgress: Double // 0..1
    public var continuousClosureProgress: Double // 0..1

    public init(
        alert: AlertLevel = .none,
        perclos: Double = 0,
        isCalibrated: Bool = false,
        calibrationProgress: Double = 0,
        continuousClosureProgress: Double = 0
    ) {
        self.alert = alert
        self.perclos = perclos
        self.isCalibrated = isCalibrated
        self.calibrationProgress = calibrationProgress
        self.continuousClosureProgress = continuousClosureProgress
    }
}
