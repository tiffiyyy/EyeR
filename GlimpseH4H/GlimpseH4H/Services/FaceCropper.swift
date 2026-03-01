//
//  FaceCropper.swift
//  GlimpseH4H
//
//

import CoreImage
import Foundation
import UIKit
import Vision

enum FaceCropper {
    private static let context = CIContext(options: nil)

    static func makeOrientedCGImage(from pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        return context.createCGImage(ciImage, from: ciImage.extent)
    }

    static func detectLargestFace(in cgImage: CGImage, orientation: CGImagePropertyOrientation = .up) -> VNFaceObservation? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        let faces = request.results ?? []
        return faces.max { lhs, rhs in
            lhs.boundingBox.width * lhs.boundingBox.height < rhs.boundingBox.width * rhs.boundingBox.height
        }
    }

    /// Bounding box is Vision-normalized (origin at bottom-left).
    static func cropFace(from cgImage: CGImage, boundingBox: CGRect, expansion: CGFloat = 0.20) -> CGImage? {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        guard width > 0, height > 0 else { return nil }

        var rect = VNImageRectForNormalizedRect(boundingBox, Int(width), Int(height))
        // Convert from Vision's bottom-left origin to CGImage's top-left origin.
        rect.origin.y = height - rect.origin.y - rect.size.height

        let expandX = rect.width * expansion
        let expandY = rect.height * expansion
        rect = rect.insetBy(dx: -expandX, dy: -expandY)
        rect = rect.intersection(CGRect(x: 0, y: 0, width: width, height: height))

        guard rect.width > 1, rect.height > 1 else { return nil }
        return cgImage.cropping(to: rect)
    }

    static func cropLargestFace(from image: UIImage, expansion: CGFloat = 0.20) -> CGImage? {
        guard let cgImage = image.cgImage else { return nil }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        guard let face = detectLargestFace(in: cgImage, orientation: orientation) else { return nil }
        return cropFace(from: cgImage, boundingBox: face.boundingBox, expansion: expansion)
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
