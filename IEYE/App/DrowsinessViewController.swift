import UIKit
import ARKit
import AVFoundation

final class DrowsinessViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    
    private let drowsinessView = DrowsinessView()
    private var detector: MetricsDetecting!
    private var viewModel: DrowsinessViewModel!
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isNightMode = false
    private let nightModeButton = UIButton(type: .system)
    private var detectionLayer = CAShapeLayer()
    private let headAngleLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // 1. UI Setup
        setupHeadAngleLabel()
        setupUIStack()
        setupDetectionLayer()

        // 2. DI & Backend logic
        let backend = DIContainer.makeBackend()
        viewModel = DIContainer.makeViewModel(backend: backend)
        detector = DIContainer.makeDetector(sceneView: sceneView, backend: backend)

        // 3. Bindings
        setupNewDetector(detector)
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async { self?.drowsinessView.render(state) }
        }

        // 4. Vision Setup
        if case .vision = backend {
            setupVisionPreview()
            sceneView.isHidden = true
        } else {
            sceneView.delegate = self
            sceneView.isHidden = false
        }
    }

    // --- UI Setup Methods ---

    private func setupUIStack() {
        nightModeButton.setTitle("Switch to Night Mode", for: .normal)
        nightModeButton.backgroundColor = .systemBlue
        nightModeButton.setTitleColor(.white, for: .normal)
        nightModeButton.layer.cornerRadius = 8 // קצת יותר מעוגל
        nightModeButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        nightModeButton.addTarget(self, action: #selector(nightModeTapped), for: .touchUpInside)
        
        let stack = UIStackView(arrangedSubviews: [nightModeButton, drowsinessView])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -5),
            
            nightModeButton.heightAnchor.constraint(equalToConstant: 40),
            nightModeButton.widthAnchor.constraint(equalToConstant: 180),
            drowsinessView.heightAnchor.constraint(equalToConstant: 80),
            drowsinessView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.95)
        ])
    }

    private func setupHeadAngleLabel() {
        headAngleLabel.translatesAutoresizingMaskIntoConstraints = false
        headAngleLabel.textColor = .yellow
        headAngleLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        headAngleLabel.textAlignment = .center
        headAngleLabel.numberOfLines = 0
        view.addSubview(headAngleLabel)
        view.bringSubviewToFront(headAngleLabel)

        NSLayoutConstraint.activate([
            headAngleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            headAngleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10)
        ])
    }

    private func setupDetectionLayer() {
        detectionLayer.strokeColor = UIColor.green.cgColor
        detectionLayer.lineWidth = 2.0
        detectionLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(detectionLayer)
    }

    // --- Logic & Bindings ---

    @objc private func nightModeTapped() {
        isNightMode.toggle()
        detector.stop()
        
        if isNightMode {
            sceneView.session.pause()
            previewLayer?.removeFromSuperlayer()
            sceneView.scene.rootNode.enumerateChildNodes { (node, _) in node.removeFromParentNode() }
            
            let arkitDetector = DIContainer.makeARKitDetector(sceneView: self.sceneView)
            sceneView.delegate = self
            setupNewDetector(arkitDetector)
            
            sceneView.isHidden = false
            let config = ARFaceTrackingConfiguration()
            sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            updateUI(isNight: true)
        } else {
            sceneView.session.pause()
            sceneView.isHidden = true
            sceneView.delegate = nil
            
            let visionDetector = DIContainer.makeVisionDetector()
            setupNewDetector(visionDetector)
            setupVisionPreview()
            updateUI(isNight: false)
        }
        detector.start()
    }

    private func setupNewDetector(_ newDetector: MetricsDetecting) {
        self.detector = newDetector
        self.detector.onMetrics = { [weak self] metrics in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.viewModel.handle(metrics: metrics)
                
                let pitchDeg = Int(metrics.pitch * 180 / .pi)
                let yawDeg = Int(metrics.yaw * 180 / .pi)
                let rollDeg = Int(metrics.roll * 180 / .pi)
                self.headAngleLabel.text = "Head Angle:\nPitch: \(pitchDeg)° | Yaw: \(yawDeg)° | Roll: \(rollDeg)°"
                
                if let rect = metrics.faceRect, !self.isNightMode {
                    let viewRect = self.view.frame
                    let w = rect.width * viewRect.width
                    let h = rect.height * viewRect.height
                    let x = rect.origin.x * viewRect.width
                    let y = (1 - rect.origin.y - rect.height) * viewRect.height
                    self.detectionLayer.path = UIBezierPath(rect: CGRect(x: x, y: y, width: w, height: h)).cgPath
                } else {
                    self.detectionLayer.path = nil
                }
            }
        }
        self.detector.onFaceLost = { [weak self] time in
            DispatchQueue.main.async { self?.viewModel.handleFaceLost(time: time) }
        }
    }

    private func updateUI(isNight: Bool) {
        nightModeButton.setTitle(isNight ? "Night Mode: ON (IR)" : "Switch to Night Mode", for: .normal)
        nightModeButton.backgroundColor = isNight ? .systemPurple : .systemBlue
    }

    private func setupVisionPreview() {
        if let visionDetector = detector as? VisionFaceMetricsDetector {
            let layer = AVCaptureVideoPreviewLayer(session: visionDetector.session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.insertSublayer(layer, at: 0)
            self.previewLayer = layer
        }
    }

    // --- Lifecycle & Delegate ---

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if ARFaceTrackingConfiguration.isSupported, !isNightMode,
           case .arkit = DIContainer.makeBackend() {
            sceneView.session.run(ARFaceTrackingConfiguration())
        }
        viewModel.start(now: CACurrentMediaTime())
        detector.start()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
        detector.stop()
        viewModel.stop()
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
}

extension DrowsinessViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard isNightMode, let device = sceneView.device else { return nil }
        let node = SCNNode(geometry: ARSCNFaceGeometry(device: device))
        node.geometry?.firstMaterial?.fillMode = .lines
        node.geometry?.firstMaterial?.diffuse.contents = UIColor.systemPurple
        return node
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        detector.handleUpdate(faceAnchor: faceAnchor)
        if isNightMode, let faceGeometry = node.geometry as? ARSCNFaceGeometry {
            faceGeometry.update(from: faceAnchor.geometry)
        }
    }
}
