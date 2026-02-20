import UIKit
import ARKit

final class DrowsinessViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!

    private let drowsinessView = DrowsinessView()
    private var detector: MetricsDetecting!
    private var viewModel: DrowsinessViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        // 1. Set the delegate so this class receives face data
        sceneView.delegate = self

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
            // Also wrap UI-related state changes in main thread if necessary
            DispatchQueue.main.async {
                self?.viewModel.handleFaceLost(time: time)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 2. Start the ARFaceTracking session
        let configuration = ARFaceTrackingConfiguration()
        sceneView.session.run(configuration)

        let now = CACurrentMediaTime()
        viewModel.start(now: now)
        detector.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 3. Pause the session to save battery/resources
        sceneView.session.pause()
        
        detector.stop()
        viewModel.stop()
    }
}

// MARK: - ARSCNViewDelegate
// This extension catches the face movements and sends them to your detector
extension DrowsinessViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
        // Pass the face data to your detector logic
        detector.handleUpdate(faceAnchor: faceAnchor)
    }
}
