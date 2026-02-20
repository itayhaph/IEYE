//
//  DrowsinessEvaluator.swift
//  IEYE
//
//  Created by Itay Haphiloni on 19/02/2026.
//

import Foundation

public final class DrowsinessEvaluator {

    // MARK: - Tuning
    private let calibrationDuration: TimeInterval = 6.0
    private let smoothingAlpha: Float = 0.25
    private let perclosWindow: TimeInterval = 60.0

    private let perclosWarning: Double = 0.22
    private let perclosAlarm: Double = 0.35

    private let closedContinuousForAlarm: TimeInterval = 1.2

    // MARK: - Baseline thresholds (computed after calibration)
    private var closeThreshold: Float = 0.80
    private var openThreshold: Float  = 0.55

    // MARK: - State
    private enum EyeState { case open, closed }
    private var eyeState: EyeState = .open

    private var calibrationStart: TimeInterval?
    private var calibrationSamples: [Float] = []
    private(set) var isCalibrated: Bool = false

    private var smoothedLeft: Float = 0
    private var smoothedRight: Float = 0

    private var closedStartTime: TimeInterval?

    private struct WindowSample { let time: TimeInterval; let isClosed: Bool }
    private var windowSamples: [WindowSample] = []

    // Face lost
    private var lastFaceSeenTime: TimeInterval = 0
    private let faceLostTimeout: TimeInterval = 1.0
    private var isFaceLost: Bool = true

    public init() {}

    public func reset(now: TimeInterval) {
        calibrationStart = nil
        calibrationSamples.removeAll()
        isCalibrated = false

        smoothedLeft = 0
        smoothedRight = 0

        eyeState = .open
        closedStartTime = nil

        windowSamples.removeAll()

        lastFaceSeenTime = now
        isFaceLost = true
    }

    public func ingestFaceLost(at timestamp: TimeInterval) -> DrowsinessState {
        // Called periodically by detector update loop
        if timestamp - lastFaceSeenTime > faceLostTimeout {
            isFaceLost = true
            return makeState(now: timestamp, alert: .noFace)
        }
        return makeState(now: timestamp, alert: .none) // won't be used usually
    }

    public func ingest(metrics: FaceMetrics) -> DrowsinessState {
        let now = metrics.timestamp
        lastFaceSeenTime = now
        isFaceLost = false

        // Smooth
        smoothedLeft = smooth(newValue: metrics.blinkLeft, oldValue: smoothedLeft, alpha: smoothingAlpha)
        smoothedRight = smooth(newValue: metrics.blinkRight, oldValue: smoothedRight, alpha: smoothingAlpha)

        // Calibration
        var calibrationProgress: Double = 0
        if calibrationStart == nil {
            calibrationStart = now
            calibrationSamples.removeAll(keepingCapacity: true)
        }
        if let start = calibrationStart, !isCalibrated {
            let elapsed = now - start
            calibrationProgress = min(1.0, elapsed / calibrationDuration)

            if elapsed <= calibrationDuration {
                let avg = (smoothedLeft + smoothedRight) / 2
                if avg < 0.35 { calibrationSamples.append(avg) }
            } else {
                finalizeCalibration()
            }
        }

        // Eye state with hysteresis
        let bothClosed = smoothedLeft > closeThreshold && smoothedRight > closeThreshold
        let bothOpen   = smoothedLeft < openThreshold  && smoothedRight < openThreshold

        switch eyeState {
        case .open:
            if bothClosed {
                eyeState = .closed
                closedStartTime = now
            }
        case .closed:
            if bothOpen {
                eyeState = .open
                closedStartTime = nil
            }
        }

        // PERCLOS samples
        appendWindowSample(time: now, isClosed: eyeState == .closed)
        let perclos = computePerclos()

        // Alert decision
        let alert: AlertLevel
        if isFaceLost {
            alert = .noFace
        } else if !isCalibrated {
            // before calibration: only continuous closure safety net
            alert = isContinuousClosedLongEnough(now: now) ? .alarm : .none
        } else if isContinuousClosedLongEnough(now: now) {
            alert = .alarm
        } else if perclos >= perclosAlarm {
            alert = .alarm
        } else if perclos >= perclosWarning {
            alert = .warning
        } else {
            alert = .none
        }

        // Progress for UI
        let continuousProgress: Double = {
            guard eyeState == .closed, let start = closedStartTime else { return 0 }
            return min(1.0, (now - start) / closedContinuousForAlarm)
        }()

        return DrowsinessState(
            alert: alert,
            perclos: perclos,
            isCalibrated: isCalibrated,
            calibrationProgress: calibrationProgress,
            continuousClosureProgress: continuousProgress
        )
    }

    // MARK: - Helpers
    private func finalizeCalibration() {
        defer { isCalibrated = true }
        guard calibrationSamples.count >= 30 else { return }

        let medianOpen = median(of: calibrationSamples)
        let open = clamp(medianOpen + 0.25, 0.35, 0.70)
        let close = clamp(medianOpen + 0.60, 0.70, 0.92)

        openThreshold = open
        closeThreshold = close
    }

    private func appendWindowSample(time: TimeInterval, isClosed: Bool) {
        windowSamples.append(.init(time: time, isClosed: isClosed))

        let cutoff = time - perclosWindow
        if windowSamples.count > 5 {
            var idx = 0
            while idx < windowSamples.count, windowSamples[idx].time < cutoff { idx += 1 }
            if idx > 0 { windowSamples.removeFirst(idx) }
        }
    }

    private func computePerclos() -> Double {
        guard !windowSamples.isEmpty else { return 0 }
        let closedCount = windowSamples.reduce(into: 0) { $0 += $1.isClosed ? 1 : 0 }
        return Double(closedCount) / Double(windowSamples.count)
    }

    private func isContinuousClosedLongEnough(now: TimeInterval) -> Bool {
        guard eyeState == .closed, let start = closedStartTime else { return false }
        return (now - start) >= closedContinuousForAlarm
    }

    private func makeState(now: TimeInterval, alert: AlertLevel) -> DrowsinessState {
        // lightweight snapshot when face is lost
        let perclos = computePerclos()
        return DrowsinessState(
            alert: alert,
            perclos: perclos,
            isCalibrated: isCalibrated,
            calibrationProgress: calibrationProgress(now: now),
            continuousClosureProgress: 0
        )
    }

    private func calibrationProgress(now: TimeInterval) -> Double {
        guard let start = calibrationStart, !isCalibrated else { return 1 }
        return min(1.0, (now - start) / calibrationDuration)
    }

    private func smooth(newValue: Float, oldValue: Float, alpha: Float) -> Float {
        alpha * newValue + (1 - alpha) * oldValue
    }

    private func clamp(_ v: Float, _ lo: Float, _ hi: Float) -> Float {
        min(max(v, lo), hi)
    }

    private func median(of arr: [Float]) -> Float {
        let s = arr.sorted()
        let n = s.count
        if n == 0 { return 0 }
        if n % 2 == 1 { return s[n/2] }
        return (s[n/2 - 1] + s[n/2]) / 2
    }
}
