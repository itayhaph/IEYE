import Foundation
import ARKit

public final class ARKitFaceMetricsDetector: NSObject, MetricsDetecting {

    public var onMetrics: ((FaceMetrics) -> Void)?
    public var onFaceLost: ((TimeInterval) -> Void)?

    private let sceneView: ARSCNView
    private var isRunning = false
    private var lastFaceSeenTime: TimeInterval = 0
    private let faceLostTickInterval: TimeInterval = 0.12
    private var lastFaceLostTick: TimeInterval = 0

    public init(sceneView: ARSCNView) {
        self.sceneView = sceneView
        super.init()
    }

    public func start() {
        guard ARFaceTrackingConfiguration.isSupported else {
            isRunning = false
            return
        }

        // Configuration is now handled in viewWillAppear of the ViewController
        // to ensure the session starts exactly when the view is ready.
        isRunning = true
        let now = CACurrentMediaTime()
        lastFaceSeenTime = now
        lastFaceLostTick = now
    }

    public func stop() {
        isRunning = false
        // session.pause() is now handled by the ViewController for better lifecycle management.
    }

    // This is the new required method from the updated MetricsDetecting protocol
    public func handleUpdate(faceAnchor: ARFaceAnchor) {
        guard isRunning else { return }

        let now = CACurrentMediaTime()
        lastFaceSeenTime = now

        // ARKit blendShapes provide values from 0.0 (open) to 1.0 (closed)
        let left = faceAnchor.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0
        let right = faceAnchor.blendShapes[.eyeBlinkRight]?.floatValue ?? 0

        // Image of ARKit face anchor blend shapes for eyeBlinkLeft and eyeBlinkRight
        
        onMetrics?(FaceMetrics(timestamp: now, blinkLeft: left, blinkRight: right))
    }

    // We keep this to monitor if the face disappears entirely for > 1 second
    public func checkFaceStatus(atTime time: TimeInterval) {
        guard isRunning else { return }

        if time - lastFaceLostTick >= faceLostTickInterval {
            lastFaceLostTick = time

            if time - lastFaceSeenTime > 1.0 {
                onFaceLost?(time)
            }
        }
    }
}
