import Foundation

public struct FaceMetrics: Equatable {
    public let timestamp: TimeInterval
    public let blinkLeft: Float     // 0..1 (0=open, 1=closed)
    public let blinkRight: Float    // 0..1 (0=open, 1=closed)
    public let faceRect: CGRect?
    
    public init(timestamp: TimeInterval, blinkLeft: Float, blinkRight: Float, faceRect: CGRect? = nil) {
        self.timestamp = timestamp
        self.blinkLeft = blinkLeft
        self.blinkRight = blinkRight
        self.faceRect = faceRect
    }

    public var blinkAvg: Float { (blinkLeft + blinkRight) / 2 }
}
