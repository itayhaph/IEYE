import Foundation
import CoreImage
import Vision

public final class ImageProcessingService {
    
    private let context = CIContext()
    
    public init() {}
    
    /// Processes the raw pixel buffer to demonstrate classical Computer Vision techniques.
    /// This includes cropping, grayscale conversion, and binarization (thresholding).
    public func processEyeRegion(pixelBuffer: CVPixelBuffer, faceBoundingBox: CGRect, eyeLandmarks: VNFaceLandmarkRegion2D) {
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let imageSize = ciImage.extent.size
        
        // 1. Crop: Calculate the absolute bounding box of the eye
        let eyeRect = calculateAbsoluteBoundingBox(
            normalizedPoints: eyeLandmarks.normalizedPoints,
            faceBoundingBox: faceBoundingBox,
            imageSize: imageSize
        )
        
        // Crop the original image to isolate the eye region
        let croppedEyeImage = ciImage.cropped(to: eyeRect)
        
        // 2. Grayscale: Convert the cropped RGB image to a single channel (Grayscale)
        guard let grayscaleFilter = CIFilter(name: "CIColorControls") else { return }
        grayscaleFilter.setValue(croppedEyeImage, forKey: kCIInputImageKey)
        grayscaleFilter.setValue(0.0, forKey: kCIInputSaturationKey) // Remove color saturation
        
        guard let grayImage = grayscaleFilter.outputImage else { return }
        
        // 3. Binarization (Thresholding): Differentiate the dark pupil from the white sclera/skin
        // By applying extreme contrast, we simulate a hard threshold function.
        guard let thresholdFilter = CIFilter(name: "CIColorControls") else { return }
        thresholdFilter.setValue(grayImage, forKey: kCIInputImageKey)
        thresholdFilter.setValue(50.0, forKey: kCIInputContrastKey)   // High contrast acts as a step function
        thresholdFilter.setValue(0.4, forKey: kCIInputBrightnessKey)  // Threshold cutoff level
        
        guard let binaryImage = thresholdFilter.outputImage else { return }
        
        // NOTE FOR THE REPORT: At this point, 'binaryImage' is a black-and-white image.
        // In a purely classical approach, we would count the black pixels to determine if the eye is open or closed.
    }
    
    /// Helper: Converts Vision's normalized coordinate system into absolute pixel coordinates
    private func calculateAbsoluteBoundingBox(normalizedPoints: [CGPoint], faceBoundingBox: CGRect, imageSize: CGSize) -> CGRect {
        
        // Find min and max X, Y in normalized face coordinates
        let minX = normalizedPoints.map { $0.x }.min() ?? 0
        let maxX = normalizedPoints.map { $0.x }.max() ?? 0
        let minY = normalizedPoints.map { $0.y }.min() ?? 0
        let maxY = normalizedPoints.map { $0.y }.max() ?? 0
        
        // Convert normalized face bounding box to absolute image coordinates
        let faceRect = CGRect(
            x: faceBoundingBox.minX * imageSize.width,
            y: (1 - faceBoundingBox.maxY) * imageSize.height, // Vision's Y axis is flipped
            width: faceBoundingBox.width * imageSize.width,
            height: faceBoundingBox.height * imageSize.height
        )
        
        // Map the eye's normalized coordinates to the absolute face rectangle
        // We add a small padding (e.g., multiplier of 1.2) to capture the whole eye
        let eyeWidth = (maxX - minX) * faceRect.width
        let eyeHeight = (maxY - minY) * faceRect.height
        
        let eyeRect = CGRect(
            x: faceRect.minX + (minX * faceRect.width),
            y: faceRect.minY + (minY * faceRect.height),
            width: eyeWidth * 1.2,
            height: eyeHeight * 1.2
        )
        
        return eyeRect
    }
}
