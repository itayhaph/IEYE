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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // 1. UI Setup
        setupDrowsinessView()
        setupNightModeButton()
        setupDetectionLayer()

        // 2. DI & Backend logic
        let backend = DIContainer.makeBackend()
        viewModel = DIContainer.makeViewModel(backend: backend)
        detector = DIContainer.makeDetector(sceneView: sceneView, backend: backend)

        // 3. Bindings & Initial Setup
        setupNewDetector(detector)
        
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async { self?.drowsinessView.render(state) }
        }

        // 4. Vision Specific Setup
        if case .vision = backend {
            setupVisionPreview()
            sceneView.isHidden = true
        } else {
            sceneView.delegate = self
            sceneView.isHidden = false
        }
    }

    private func setupDetectionLayer() {
        detectionLayer.strokeColor = UIColor.green.cgColor
        detectionLayer.lineWidth = 2.0
        detectionLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(detectionLayer)
    }

    private func setupNightModeButton() {
        nightModeButton.translatesAutoresizingMaskIntoConstraints = false
        nightModeButton.setTitle("Switch to Night Mode", for: .normal)
        nightModeButton.backgroundColor = .systemBlue
        nightModeButton.setTitleColor(.white, for: .normal)
        nightModeButton.layer.cornerRadius = 10
        nightModeButton.addTarget(self, action: #selector(nightModeTapped), for: .touchUpInside)
        
        view.addSubview(nightModeButton)
        view.bringSubviewToFront(nightModeButton)
        
        NSLayoutConstraint.activate([
            nightModeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nightModeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            nightModeButton.widthAnchor.constraint(equalToConstant: 220),
            nightModeButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc private func nightModeTapped() {
        isNightMode.toggle()
        detector.stop()
        
        if isNightMode {
            // --- מעבר ל-ARKit (Night Mode) ---
            sceneView.session.pause()
            previewLayer?.removeFromSuperlayer()
            
            // ניקוי צמתים ישנים
            sceneView.scene.rootNode.enumerateChildNodes { (node, _) in node.removeFromParentNode() }
            
            let arkitDetector = DIContainer.makeARKitDetector(sceneView: self.sceneView)
            sceneView.delegate = self // ה-VC הוא ה-delegate כדי להפעיל את ה-renderer
            
            setupNewDetector(arkitDetector)
            
            sceneView.isHidden = false
            let config = ARFaceTrackingConfiguration()
            sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            
            updateUI(isNight: true)
        } else {
            // --- חזרה ל-Vision (Standard Mode) ---
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
                
                // 1. לוגיקת עייפות
                self.viewModel.handle(metrics: metrics)
                
                // 2. ויזואליזציה של הריבוע הירוק (רק ב-Vision)
                if let rect = metrics.faceRect, !self.isNightMode {
                    let viewRect = self.view.frame
                    let w = rect.width * viewRect.width
                    let h = rect.height * viewRect.height
                    let x = rect.origin.x * viewRect.width
                    let y = (1 - rect.origin.y - rect.height) * viewRect.height
                    
                    let drawRect = CGRect(x: x, y: y, width: w, height: h)
                    self.detectionLayer.path = UIBezierPath(rect: drawRect).cgPath
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
        let title = isNight ? "Night Mode: ON (IR)" : "Switch to Night Mode"
        let color = isNight ? UIColor.systemPurple : UIColor.systemBlue
        nightModeButton.setTitle(title, for: .normal)
        nightModeButton.backgroundColor = color
    }
    
    private func setupDrowsinessView() {
        drowsinessView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(drowsinessView)
        NSLayoutConstraint.activate([
            drowsinessView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            drowsinessView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            drowsinessView.topAnchor.constraint(equalTo: view.topAnchor),
            drowsinessView.heightAnchor.constraint(equalToConstant: 140)
        ])
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if ARFaceTrackingConfiguration.isSupported, !isNightMode,
           case .arkit = DIContainer.makeBackend() {
            let configuration = ARFaceTrackingConfiguration()
            sceneView.session.run(configuration)
        }
        let now = CACurrentMediaTime()
        viewModel.start(now: now)
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

// MARK: - ARSCNViewDelegate
extension DrowsinessViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard isNightMode, let device = sceneView.device else { return nil }
        let faceGeometry = ARSCNFaceGeometry(device: device)
        let node = SCNNode(geometry: faceGeometry)
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
