import Foundation
import ARKit // You need this import to use ARFaceAnchor

public protocol MetricsDetecting: AnyObject {
    var onMetrics: ((FaceMetrics) -> Void)? { get set }
    var onFaceLost: ((TimeInterval) -> Void)? { get set }
    
    // ADD THIS LINE:
    func handleUpdate(faceAnchor: ARFaceAnchor)
    
    func start()
    func stop()
}
