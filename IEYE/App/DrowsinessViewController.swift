import UIKit
import ARKit
import AVFoundation

final class DrowsinessViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!

    private let drowsinessView = DrowsinessView()
    private var detector: MetricsDetecting!
    private var viewModel: DrowsinessViewModel!
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // 1. UI Setup
        setupDrowsinessView()

        // 2. DI & Backend logic
        let backend = DIContainer.makeBackend()
        viewModel = DIContainer.makeViewModel(backend: backend)
        detector = DIContainer.makeDetector(sceneView: sceneView, backend: backend)

        // 3. Vision Specific Setup: Add Camera Preview
        if case .vision = backend {
            setupVisionPreview()
            sceneView.isHidden = true // Hide ARKit view if using Vision
        } else {
            sceneView.delegate = self
            sceneView.isHidden = false
        }

        // 4. Bindings
        setupBindings()
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
        // We cast the detector to access its AVCaptureSession
        if let visionDetector = detector as? VisionFaceMetricsDetector {
            let layer = AVCaptureVideoPreviewLayer(session: visionDetector.session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            // Insert at index 0 so it's behind the drowsinessView text
            view.layer.insertSublayer(layer, at: 0)
            self.previewLayer = layer
        }
    }

    private func setupBindings() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.drowsinessView.render(state)
            }
        }

        detector.onMetrics = { [weak self] metrics in
            DispatchQueue.main.async {
                self?.viewModel.handle(metrics: metrics)
            }
        }

        detector.onFaceLost = { [weak self] time in
            DispatchQueue.main.async {
                self?.viewModel.handleFaceLost(time: time)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Only run ARKit session if supported and selected
        if ARFaceTrackingConfiguration.isSupported,
           case .arkit = DIContainer.makeBackend() {
            let configuration = ARFaceTrackingConfiguration()
            sceneView.session.run(configuration)
        }

        let now = CACurrentMediaTime()
        viewModel.start(now: now)
        detector.start()
        
        // Prevent screen dimming during the demo/driving
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
        detector.stop()
        viewModel.stop()
        
        // Re-enable screen dimming when leaving the app
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure preview layer stays full screen on rotation
        previewLayer?.frame = view.bounds
    }
}

// MARK: - ARSCNViewDelegate
extension DrowsinessViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        detector.handleUpdate(faceAnchor: faceAnchor)
    }
}
