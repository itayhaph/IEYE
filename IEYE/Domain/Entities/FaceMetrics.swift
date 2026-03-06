import Foundation

public struct FaceMetrics: Equatable {
    public let timestamp: TimeInterval
    public let blinkLeft: Float     // 0..1 (0=open, 1=closed)
    public let blinkRight: Float    // 0..1 (0=open, 1=closed)
    public let faceRect: CGRect?
    public let pitch: Float
    public let yaw: Float
    public let roll: Float
    
    public init(timestamp: TimeInterval, blinkLeft: Float, blinkRight: Float, faceRect: CGRect? = nil, pitch: Float = 0, yaw: Float = 0, roll: Float = 0) {
        self.timestamp = timestamp
        self.blinkLeft = blinkLeft
        self.blinkRight = blinkRight
        self.faceRect = faceRect
        self.pitch = pitch
        self.yaw = yaw
        self.roll = roll
    }

    public var blinkAvg: Float { (blinkLeft + blinkRight) / 2 }
}
