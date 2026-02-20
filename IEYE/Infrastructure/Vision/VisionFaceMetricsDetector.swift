//
//  VisionFaceMetricsDetector.swift
//  IEYE
//
//  Created by Itay Haphiloni on 19/02/2026.
//

import Foundation
import AVFoundation
import Vision
import CoreImage
import CoreGraphics
import ARKit

public final class VisionFaceMetricsDetector: NSObject, MetricsDetecting {

    public var onMetrics: ((FaceMetrics) -> Void)?
    public var onFaceLost: ((TimeInterval) -> Void)?

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "vision.detector.queue")

    private var lastFaceSeenTime: TimeInterval = 0
    private let faceLostTimeout: TimeInterval = 1.0

    private var isRunning = false
    private var lastRequestTime: TimeInterval = 0
    private let maxFPS: Double = 12 // להגביל עומס CPU

    public override init() {
        super.init()
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        configureCapture()
        session.startRunning()

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

        // Input (front camera)
        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        // Output
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

        // Mirror for front camera + orientation (בסיסי)
        if let conn = videoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                // Portrait corresponds to 90° rotation angle
                conn.videoRotationAngle = 90
            } else {
                conn.videoOrientation = .portrait
            }
            conn.isVideoMirrored = true
        }

        session.commitConfiguration()
    }

    private func handleFaceLostIfNeeded(now: TimeInterval) {
        if now - lastFaceSeenTime > faceLostTimeout {
            onFaceLost?(now)
        }
    }

    private func process(pixelBuffer: CVPixelBuffer, now: TimeInterval) {
        // FPS throttle
        if now - lastRequestTime < (1.0 / maxFPS) {
            handleFaceLostIfNeeded(now: now)
            return
        }
        lastRequestTime = now

        let request = VNDetectFaceLandmarksRequest { [weak self] req, _ in
            guard let self else { return }

            guard let face = (req.results as? [VNFaceObservation])?.first,
                  let landmarks = face.landmarks
            else {
                self.handleFaceLostIfNeeded(now: now)
                return
            }

            self.lastFaceSeenTime = now

            // eyes landmarks
            guard let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye else {
                self.handleFaceLostIfNeeded(now: now)
                return
            }

            // EAR -> convert to closedness 0..1
            let leftClosed = self.eyeClosedness(from: leftEye)
            let rightClosed = self.eyeClosedness(from: rightEye)

            self.onMetrics?(FaceMetrics(timestamp: now, blinkLeft: leftClosed, blinkRight: rightClosed))
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            handleFaceLostIfNeeded(now: now)
        }
    }

    // EAR-like closedness mapping from eye contour points
    // NOTE: Vision gives normalized points in eye region coordinates; this is an approximation.
    private func eyeClosedness(from region: VNFaceLandmarkRegion2D) -> Float {
        // Minimal robust approach: use vertical span / horizontal span of eye polygon
        let pts = region.normalizedPoints
        guard pts.count >= 6 else { return 0 }

        var minX: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = -.greatestFiniteMagnitude
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxY: CGFloat = -.greatestFiniteMagnitude

        for p in pts {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }

        let width: CGFloat = max(0.0001, maxX - minX)
        let height: CGFloat = max(0.0, maxY - minY)

        // openness ratio
        let ratio: CGFloat = height / width // פתוח יותר => ratio גבוה יותר

        // Map ratio to closedness 0..1 (צריך כיול!)
        // הערכים בפועל משתנים בין אנשים/תאורה; מתחילים מניחושים:
        let openRatio: CGFloat = 0.30
        let closedRatio: CGFloat = 0.12

        if ratio >= openRatio { return 0 }      // open -> 0 closedness
        if ratio <= closedRatio { return 1 }    // closed -> 1 closedness

        // linear interpolation
        let t: CGFloat = (openRatio - ratio) / (openRatio - closedRatio)
        return Float(max(0, min(1, t)))
    }
    

    // Add this to satisfy the protocol requirements
    public func handleUpdate(faceAnchor: ARFaceAnchor) {
        // Vision backend handles data through the AVCapture session
        // so we don't need to do anything here.
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

