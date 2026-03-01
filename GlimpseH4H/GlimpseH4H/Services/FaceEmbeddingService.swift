//
//  FaceEmbeddingService.swift
//  GlimpseH4H
//
//  Uses Apple's Vision/CoreML stack to generate face embeddings
//  from still images and live camera frames. This is intentionally
//  model-agnostic: drop a compatible CoreML model named
//  "FaceEmbedding.mlmodel" into the app target and it will be used.
//

import Foundation
import Vision
import CoreML
import UIKit

/// Provides face embeddings for onboarding photos and live camera frames.
final class FaceEmbeddingService {
    static let shared = FaceEmbeddingService()

    private let vnModel: VNCoreMLModel?

    private init() {
        // Attempt to load a compiled CoreML model named "FaceEmbedding.mlmodelc"
        if let url = Bundle.main.url(forResource: "FaceEmbedding", withExtension: "mlmodelc"),
           let coreMLModel = try? MLModel(contentsOf: url),
           let visionModel = try? VNCoreMLModel(model: coreMLModel) {
            vnModel = visionModel
        } else {
            vnModel = nil
        }
    }

    /// Whether a face-embedding model is loaded and recognition is available.
    var isModelAvailable: Bool { vnModel != nil }

    /// Returns an embedding vector for the primary face in a UIImage, if possible.
    /// Uses Vision to detect the largest face, then runs the CoreML model on that region.
    func embedding(from image: UIImage) -> [Float]? {
        guard let cgImage = image.cgImage else { return nil }
        guard let vnModel else { return nil }

        // 1) Detect faces in the image.
        let faceDetection = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([faceDetection])
        } catch {
            return nil
        }

        guard let observations = faceDetection.results as? [VNFaceObservation],
              let mainFace = observations.max(by: { a, b in
                  a.boundingBox.width * a.boundingBox.height < b.boundingBox.width * b.boundingBox.height
              }) else {
            return nil
        }

        // 2) Run the CoreML model on the detected face region.
        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .scaleFill
        request.regionOfInterest = mainFace.boundingBox

        let embedHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try embedHandler.perform([request])
        } catch {
            return nil
        }

        guard let result = request.results?.first as? VNCoreMLFeatureValueObservation,
              let array = result.featureValue.multiArrayValue else {
            return nil
        }

        return array.toFloatArray()
    }

    /// Returns an embedding vector for a face region within a CVPixelBuffer.
    /// `boundingBox` is in Vision's normalized coordinates (origin bottom-left).
    func embedding(from pixelBuffer: CVPixelBuffer, boundingBox: CGRect) -> [Float]? {
        guard let vnModel else { return nil }

        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .scaleFill
        request.regionOfInterest = boundingBox

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .leftMirrored,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let result = request.results?.first as? VNCoreMLFeatureValueObservation,
              let array = result.featureValue.multiArrayValue else {
            return nil
        }

        return array.toFloatArray()
    }
}

private extension MLMultiArray {
    func toFloatArray() -> [Float] {
        let count = self.count
        var result = [Float](repeating: 0, count: count)
        for i in 0..<count {
            result[i] = self[i].floatValue
        }
        return result
    }
}

