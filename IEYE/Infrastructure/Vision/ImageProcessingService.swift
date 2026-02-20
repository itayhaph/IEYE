//
//  ImageProcessingService.swift
//
//  IEYE
//
//  Created by Itay Haphiloni on 19/02/2026.
//

import CoreVideo
import Vision
import CoreGraphics

/// A lightweight, optional image processing helper used for debug/report paths.
/// This stub keeps the build green without pulling in heavy dependencies.
public final class ImageProcessingService {
    public init() {}

    /// Optionally process an eye region for debugging. Returns an optional debug image or metrics.
    /// In this stub, we simply return nil.
    @discardableResult
    public func processEyeRegion(
        pixelBuffer: CVPixelBuffer,
        faceBoundingBox: CGRect,
        eyeLandmarks: VNFaceLandmarkRegion2D
    ) -> Any? {
        // No-op stub
        return nil
    }
}

