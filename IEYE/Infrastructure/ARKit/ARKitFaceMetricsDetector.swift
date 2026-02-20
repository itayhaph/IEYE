//
//  ARKitFaceMetricsDetector.swift
//  IEYE
//
//  Created by Itay Haphiloni on 19/02/2026.
//

import Foundation
import ARKit
import SceneKit

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
            // No face tracking available; still tick "face lost"
            isRunning = false
            return
        }

        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = true

        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        isRunning = true
        let now = CACurrentMediaTime()
        lastFaceSeenTime = now
        lastFaceLostTick = now
    }

    public func stop() {
        isRunning = false
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard isRunning, let faceAnchor = anchor as? ARFaceAnchor else { return }

        let now = CACurrentMediaTime()
        lastFaceSeenTime = now

        let left = faceAnchor.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0
        let right = faceAnchor.blendShapes[.eyeBlinkRight]?.floatValue ?? 0

        onMetrics?(FaceMetrics(timestamp: now, blinkLeft: left, blinkRight: right))
    }

    public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard isRunning else { return }

        // Throttle face-lost callback
        if time - lastFaceLostTick >= faceLostTickInterval {
            lastFaceLostTick = time

            // If no face updates recently -> notify
            if time - lastFaceSeenTime > 1.0 {
                onFaceLost?(time)
            }
        }
    }
}
