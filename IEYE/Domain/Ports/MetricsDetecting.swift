import Foundation
import ARKit

public protocol MetricsDetecting: AnyObject {
    var onMetrics: ((FaceMetrics) -> Void)? { get set }
    var onFaceLost: ((TimeInterval) -> Void)? { get set }
    
    func handleUpdate(faceAnchor: ARFaceAnchor)
    func start()
    func stop()
}
