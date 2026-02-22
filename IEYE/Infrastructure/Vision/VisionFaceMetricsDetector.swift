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
    private let maxHistorySamples = 4 // כמות פריימים לממוצע נע. הגדל ל-6 אם עדיין יש אזעקות שווא במצמוץ.
    
    private let imageProcessor = ImageProcessingService()
    
    public override init() {
        super.init()
    }
    
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        
        configureCapture()
        
        // הרצת הסשן בתור רקע כדי לא לחסום את ה-UI
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

    // פונקציית עזר לחישוב ממוצע נע
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
        
        let request = VNDetectFaceLandmarksRequest { [weak self] req, _ in
            guard let self = self else { return }
            
            guard let face = (req.results as? [VNFaceObservation])?.first,
                  let landmarks = face.landmarks else {
                self.handleFaceLostIfNeeded(now: now)
                return
            }
            
            self.lastFaceSeenTime = now
            
            guard let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye else {
                self.handleFaceLostIfNeeded(now: now)
                return
            }
            
            // 1. עיבוד תמונה קלאסי (אופציונלי להדגמה)
            self.imageProcessor.processEyeRegion(
                pixelBuffer: pixelBuffer,
                faceBoundingBox: face.boundingBox,
                eyeLandmarks: leftEye
            )
            
            // 2. חישוב EAR גולמי
            let leftRaw = self.calculateEARClosedness(from: leftEye)
            let rightRaw = self.calculateEARClosedness(from: rightEye)
            
            // 3. החלקת נתונים (Temporal Filtering)
            let leftSmoothed = self.smoothValue(leftRaw, history: &self.leftEyeHistory)
            let rightSmoothed = self.smoothValue(rightRaw, history: &self.rightEyeHistory)
            
            // הדפסה לדיבאג כדי לראות את ההבדל בין הערך הגולמי למוחלק
            // print("EAR -> Raw: \(leftRaw), Smoothed: \(leftSmoothed)")
            
            self.onMetrics?(FaceMetrics(timestamp: now, blinkLeft: leftSmoothed, blinkRight: rightSmoothed))
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            handleFaceLostIfNeeded(now: now)
        }
    }
    
    private func calculateEARClosedness(from region: VNFaceLandmarkRegion2D) -> Float {
        let pts = region.normalizedPoints
        guard pts.count >= 6 else { return 0 }

        // חישוב רוחב העין (אופקי)
        let leftCorner = pts.min(by: { $0.x < $1.x })!
        let rightCorner = pts.max(by: { $0.x < $1.x })!
        let hDist = Float(hypot(leftCorner.x - rightCorner.x, leftCorner.y - rightCorner.y))

        // חישוב גובה העין (אנכי) ע"י חלוקת העין לחצאים למניעת רעש
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
        
        // ספי EAR מותאמים אישית למניעת רגישות יתר
        let openEAR: Float = 0.22
        let closedEAR: Float = 0.13 // הורדנו מעט כדי שיהיה צורך בסגירה ברורה יותר

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
