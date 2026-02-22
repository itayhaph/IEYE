//
//  DIContainer.swift
//  IEYE
//
//  Created by Itay Haphiloni on 19/02/2026.
//

import ARKit

enum DetectionBackend {
    case arkit
    case vision
}

final class DIContainer {

    static func makeBackend() -> DetectionBackend {
        // Prefer ARKit when device supports face tracking; otherwise fall back to Vision
//        if ARFaceTrackingConfiguration.isSupported {
//            return .arkit
//        } else {
        return .vision
    }

    // בתוך DIContainer
    static func makeARKitDetector(sceneView: ARSCNView) -> MetricsDetecting {
        return ARKitFaceMetricsDetector(sceneView: sceneView)
    }
    
    static func makeVisionDetector() -> MetricsDetecting {
        return VisionFaceMetricsDetector()
    }
    
    static func makeViewModel(backend: DetectionBackend) -> DrowsinessViewModel {
        // Build evaluator and audio alerting dependencies
        let evaluator = DrowsinessEvaluator()
        let audio = AudioAlertService()
        return DrowsinessViewModel(evaluator: evaluator, audio: audio)
    }

    static func makeDetector(sceneView: ARSCNView, backend: DetectionBackend) -> MetricsDetecting {
        switch backend {
        case .arkit:
            return ARKitFaceMetricsDetector(sceneView: sceneView)
        case .vision:
            return VisionFaceMetricsDetector()
        }
    }
}
