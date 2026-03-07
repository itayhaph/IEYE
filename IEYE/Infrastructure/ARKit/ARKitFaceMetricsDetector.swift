import Foundation
import ARKit

public final class ARKitFaceMetricsDetector: NSObject, MetricsDetecting, ARSCNViewDelegate {

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

        isRunning = true
        let now = CACurrentMediaTime()
        lastFaceSeenTime = now
        lastFaceLostTick = now
    }

    public func stop() {
        isRunning = false
    }

    // מימוש ה-Delegate - זה מה שיגרום לזה לעבוד במעבר ידני
    public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        handleUpdate(faceAnchor: faceAnchor)
    }

    public func handleUpdate(faceAnchor: ARFaceAnchor) {
        guard isRunning else { return }
        let now = CACurrentMediaTime()
        
        let transform = faceAnchor.transform
        
        let pitch = asin(-transform.columns.1.z)
        let yaw = atan2(transform.columns.0.z, transform.columns.2.z)
        let roll = atan2(transform.columns.1.x, transform.columns.1.y)
        
        let left = faceAnchor.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0
        let right = faceAnchor.blendShapes[.eyeBlinkRight]?.floatValue ?? 0
        
        onMetrics?(FaceMetrics(
            timestamp: now,
            blinkLeft: left,
            blinkRight: right,
            faceRect: nil,
            pitch: pitch,
            yaw: yaw,
            roll: roll
        ))
    }

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
