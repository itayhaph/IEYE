//
//  DrowsinessView.swift
//  IEYE
//
//  Created by Itay Haphiloni on 19/02/2026.
//

import UIKit

final class DrowsinessView: UIView {

    let statusLabel = UILabel()
    let perclosLabel = UILabel()
    let progressView = UIProgressView(progressViewStyle: .default)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2

        perclosLabel.translatesAutoresizingMaskIntoConstraints = false
        perclosLabel.font = .systemFont(ofSize: 15, weight: .medium)
        perclosLabel.textAlignment = .center

        progressView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(statusLabel)
        addSubview(perclosLabel)
        addSubview(progressView)

        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            statusLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),

            perclosLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            perclosLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            perclosLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),

            progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            progressView.topAnchor.constraint(equalTo: perclosLabel.bottomAnchor, constant: 10)
        ])
    }

    func render(_ state: DrowsinessState) {
        let perclosPct = Int((state.perclos * 100).rounded())
        perclosLabel.text = "PERCLOS (60s): \(perclosPct)%"

        if !state.isCalibrated {
            progressView.progress = Float(state.calibrationProgress)
            statusLabel.text = "Calibrating...\nKeep eyes open"
            statusLabel.textColor = .systemBlue
            return
        }

        progressView.progress = Float(state.continuousClosureProgress)

        switch state.alert {
        case .none:
            statusLabel.text = "Tracking ✅"
            statusLabel.textColor = .label
        case .warning:
            statusLabel.text = "⚠️ Warning: fatigue rising"
            statusLabel.textColor = .systemOrange
        case .alarm:
            statusLabel.text = "🛑 ALARM: Wake up!"
            statusLabel.textColor = .systemRed
        case .noFace:
            statusLabel.text = "No face detected\nAdjust camera"
            statusLabel.textColor = .systemGray
        }
    }
}
