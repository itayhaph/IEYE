//
//  ViewController.swift
//  IEYE
//
//  Created by Itay Haphiloni on 19/02/2026.
//
import UIKit
import ARKit

final class DrowsinessViewController: UIViewController {

    @IBOutlet private var sceneView: ARSCNView!

    private let drowsinessView = DrowsinessView()
    private var detector: MetricsDetecting!
    private var viewModel: DrowsinessViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        // UI overlay
        drowsinessView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(drowsinessView)
        NSLayoutConstraint.activate([
            drowsinessView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            drowsinessView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            drowsinessView.topAnchor.constraint(equalTo: view.topAnchor),
            drowsinessView.heightAnchor.constraint(equalToConstant: 140)
        ])

        // DI
        let backend = DIContainer.makeBackend()
        viewModel = DIContainer.makeViewModel(backend: backend)
        detector = DIContainer.makeDetector(sceneView: sceneView, backend: backend)

        // Bind
        viewModel.onStateChanged = { [weak self] state in
            self?.drowsinessView.render(state)
        }

        detector.onMetrics = { [weak self] metrics in
            self?.viewModel.handle(metrics: metrics)
        }

        detector.onFaceLost = { [weak self] time in
            self?.viewModel.handleFaceLost(time: time)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let now = CACurrentMediaTime()
        viewModel.start(now: now)
        detector.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        detector.stop()
        viewModel.stop()
    }
}

