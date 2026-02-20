//
//  DrowsinessViewModel.swift
//  IEYE
//
//  Created by Itay Haphiloni on 19/02/2026.
//

import Foundation

final class DrowsinessViewModel {

    private let evaluator: DrowsinessEvaluator
    private let audio: AudioAlerting

    private(set) var state = DrowsinessState()
    var onStateChanged: ((DrowsinessState) -> Void)?

    private var lastAlert: AlertLevel = .none

    init(evaluator: DrowsinessEvaluator, audio: AudioAlerting) {
        self.evaluator = evaluator
        self.audio = audio
    }

    func start(now: TimeInterval) {
        evaluator.reset(now: now)
        state = DrowsinessState(alert: .noFace, perclos: 0, isCalibrated: false, calibrationProgress: 0, continuousClosureProgress: 0)
        emit()
    }

    func handle(metrics: FaceMetrics) {
        let newState = evaluator.ingest(metrics: metrics)
        applySideEffectsIfNeeded(newState.alert)
        state = newState
        emit()
    }

    func handleFaceLost(time: TimeInterval) {
        let newState = evaluator.ingestFaceLost(at: time)
        if newState.alert == .noFace {
            applySideEffectsIfNeeded(.noFace)
            state = newState
            emit()
        }
    }

    func stop() {
        audio.stop()
    }

    private func applySideEffectsIfNeeded(_ alert: AlertLevel) {
        guard alert != lastAlert else { return }
        lastAlert = alert

        switch alert {
        case .none, .noFace:
            audio.stop()
        case .warning:
            audio.playWarning()
        case .alarm:
            audio.playAlarm()
        }
    }

    private func emit() {
        onStateChanged?(state)
    }
}
