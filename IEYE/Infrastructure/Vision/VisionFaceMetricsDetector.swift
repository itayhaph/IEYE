import Foundation
import AVFoundation
import Vision
import CoreImage
import ARKit

public final class VisionFaceMetricsDetector: NSObject, MetricsDetecting {
    
    public var onMetrics: ((FaceMetrics) -> Void)?
    public var onFaceLost: ((TimeInterval) -> Void)?
    
    public let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "vision.detector.queue")
    
    private var lastFaceSeenTime: TimeInterval = 0
    private let faceLostTimeout: TimeInterval = 1.0
    
    private var isRunning = false
    private var lastRequestTime: TimeInterval = 0
    private let maxFPS: Double = 12

    // --- מנגנון החלקת נתונים (Smoothing) למניעת אזעקות שווא ---
    private var leftEyeHistory: [Float] = []
    private var rightEyeHistory: [Float] = []
    private let maxHistorySamples = 4
    
    private let imageProcessor = ImageProcessingService()
    
    public override init() {
        super.init()
    }
    
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        
        configureCapture()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
        
        let now = CACurrentMediaTime()
        lastFaceSeenTime = now
    }
    
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        session.stopRunning()
    }
    
    private func configureCapture() {
        session.beginConfiguration()
        session.sessionPreset = .high
        
        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        
        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(videoOutput)
        
        if let conn = videoOutput.connection(with: .video) {
            conn.isVideoMirrored = true
            if #available(iOS 17.0, *) {
                conn.videoRotationAngle = 90
            } else {
                conn.videoOrientation = .portrait
            }
        }
        
        session.commitConfiguration()
    }
    
    private func handleFaceLostIfNeeded(now: TimeInterval) {
        if now - lastFaceSeenTime > faceLostTimeout {
            onFaceLost?(now)
        }
    }

    private func smoothValue(_ newValue: Float, history: inout [Float]) -> Float {
        history.append(newValue)
        if history.count > maxHistorySamples {
            history.removeFirst()
        }
        return history.reduce(0, +) / Float(history.count)
    }
    
    private func process(pixelBuffer: CVPixelBuffer, now: TimeInterval) {
        if now - lastRequestTime < (1.0 / maxFPS) {
            handleFaceLostIfNeeded(now: now)
            return
        }
        lastRequestTime = now
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        // --- שלב 1: זיהוי פנים עם Revision 3 לקבלת זוויות רציפות ---
        let rectRequest = VNDetectFaceRectanglesRequest()
        if #available(iOS 15.0, *) {
            // זה מה שמתקן את הקפיצות ב-Yaw ומחשב Pitch ו-Roll!
            rectRequest.revision = VNDetectFaceRectanglesRequestRevision3
        }
        
        do {
            try handler.perform([rectRequest])
            
            // שולפים את הפנים (עכשיו יש עליהן מידע זוויות חלק)
            guard let faces = rectRequest.results as? [VNFaceObservation], let faceRectObs = faces.first else {
                handleFaceLostIfNeeded(now: now)
                return
            }
            
            // --- שלב 2: זיהוי ציוני פנים (Landmarks) על הפנים המדויקות שמצאנו ---
            let landmarksRequest = VNDetectFaceLandmarksRequest()
            // אנחנו מכניסים את התוצאה של שלב 1 כדי לחסוך חישוב כפול ולשמור על הזוויות
            landmarksRequest.inputFaceObservations = [faceRectObs]
            
            try handler.perform([landmarksRequest])
            
            guard let faceLandmarksObs = (landmarksRequest.results as? [VNFaceObservation])?.first,
                  let landmarks = faceLandmarksObs.landmarks,
                  let leftEye = landmarks.leftEye,
                  let rightEye = landmarks.rightEye else {
                handleFaceLostIfNeeded(now: now)
                return
            }
            
            self.lastFaceSeenTime = now
            
            // עיבוד תמונה קלאסי (אופציונלי להדגמה)
            self.imageProcessor.processEyeRegion(
                pixelBuffer: pixelBuffer,
                faceBoundingBox: faceRectObs.boundingBox,
                eyeLandmarks: leftEye
            )
            
            // חישוב EAR גולמי והחלקה
            let leftRaw = self.calculateEARClosedness(from: leftEye)
            let rightRaw = self.calculateEARClosedness(from: rightEye)
            
            let leftSmoothed = self.smoothValue(leftRaw, history: &self.leftEyeHistory)
            let rightSmoothed = self.smoothValue(rightRaw, history: &self.rightEyeHistory)
            
            // שולפים את הזוויות מ-faceRectObs (שיש לו את Revision 3) ולא מה-Landmarks!
            let pitch = faceRectObs.pitch?.floatValue ?? 0
            let yaw = faceRectObs.yaw?.floatValue ?? 0
            let roll = faceRectObs.roll?.floatValue ?? 0
            
            self.onMetrics?(FaceMetrics(
                timestamp: now,
                blinkLeft: leftSmoothed,
                blinkRight: rightSmoothed,
                faceRect: faceRectObs.boundingBox,
                pitch: pitch,
                yaw: yaw,
                roll: roll
            ))
            
        } catch {
            handleFaceLostIfNeeded(now: now)
        }
    }
    
    private func calculateEARClosedness(from region: VNFaceLandmarkRegion2D) -> Float {
        let pts = region.normalizedPoints
        guard pts.count >= 6 else { return 0 }

        let leftCorner = pts.min(by: { $0.x < $1.x })!
        let rightCorner = pts.max(by: { $0.x < $1.x })!
        let hDist = Float(hypot(leftCorner.x - rightCorner.x, leftCorner.y - rightCorner.y))

        let midX = (leftCorner.x + rightCorner.x) / 2
        let leftHalf = pts.filter { $0.x < midX }
        let rightHalf = pts.filter { $0.x >= midX }
        
        func verticalSpan(in points: [CGPoint]) -> Float {
            guard let minY = points.min(by: { $0.y < $1.y })?.y,
                  let maxY = points.max(by: { $0.y < $1.y })?.y else { return 0 }
            return Float(maxY - minY)
        }

        let v1 = verticalSpan(in: leftHalf)
        let v2 = verticalSpan(in: rightHalf)

        let ear = (v1 + v2) / (2.0 * max(0.0001, hDist))
        
        let openEAR: Float = 0.22
        let closedEAR: Float = 0.13

        if ear >= openEAR { return 0.0 }
        if ear <= closedEAR { return 1.0 }

        return (openEAR - ear) / (openEAR - closedEAR)
    }
    
    public func handleUpdate(faceAnchor: ARFaceAnchor) {
        // לא רלוונטי ל-Vision Backend
    }
}

extension VisionFaceMetricsDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput,
                              didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        guard isRunning, let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let now = CACurrentMediaTime()
        process(pixelBuffer: pb, now: now)
    }
}
