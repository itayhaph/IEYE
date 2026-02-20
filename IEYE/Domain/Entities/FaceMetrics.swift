import Foundation

public struct FaceMetrics: Equatable {
    public let timestamp: TimeInterval
    public let blinkLeft: Float     // 0..1 (0=open, 1=closed)
    public let blinkRight: Float    // 0..1 (0=open, 1=closed)

    public init(timestamp: TimeInterval, blinkLeft: Float, blinkRight: Float) {
        self.timestamp = timestamp
        self.blinkLeft = blinkLeft
        self.blinkRight = blinkRight
    }

    public var blinkAvg: Float { (blinkLeft + blinkRight) / 2 }
}
