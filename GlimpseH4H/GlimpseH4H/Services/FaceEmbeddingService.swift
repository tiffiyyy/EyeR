//
//  FaceEmbeddingService.swift
//  GlimpseH4H
//
//  Loads FaceEmbedding.mlmodel(c): tries .mlmodelc first, then .mlmodel.
//  If VNCoreMLModel fails (e.g. multiarray input like koush FaceNet), uses
//  MLModel directly with manual crop/resize so recognition still works.
//

import Foundation
import Vision
import CoreML
import UIKit
import CoreImage

/// Provides face embeddings for onboarding photos and live camera frames.
final class FaceEmbeddingService {
    static let shared = FaceEmbeddingService()

    private let vnModel: VNCoreMLModel?
    /// Used when VNCoreMLModel fails (model has multiarray input).
    private let fallbackModel: MLModel?
    private let fallbackInputName: String?
    private let fallbackOutputName: String?
    private let fallbackInputHeight: Int
    private let fallbackInputWidth: Int
    /// true if model expects [1, 3, H, W] (NCHW), false if [1, H, W, 3] (NHWC).
    private let fallbackInputIsNCHW: Bool

    private init() {
        var vn: VNCoreMLModel?
        var fallback: MLModel?
        var inName: String?
        var outName: String?
        var h = 160
        var w = 160
        var isNCHW = false

        let url = Bundle.main.url(forResource: "FaceEmbedding", withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: "FaceEmbedding", withExtension: "mlmodel")

        guard let modelURL = url,
              let coreMLModel = try? MLModel(contentsOf: modelURL) else {
            vnModel = nil
            fallbackModel = nil
            fallbackInputName = nil
            fallbackOutputName = nil
            fallbackInputHeight = 160
            fallbackInputWidth = 160
            fallbackInputIsNCHW = false
            return
        }

        if let visionModel = try? VNCoreMLModel(for: coreMLModel) {
            vn = visionModel
            fallback = nil
            inName = nil
            outName = nil
        } else {
            vn = nil
            fallback = coreMLModel
            let desc = coreMLModel.modelDescription
            inName = desc.inputDescriptionsByName.first?.key
            outName = desc.outputDescriptionsByName.first?.key
            if let constraint = desc.inputDescriptionsByName.first?.value.multiArrayConstraint {
                let shape = constraint.shape.map { $0.intValue }
                if shape.count == 4 {
                    if shape[1] == 3 {
                        isNCHW = true
                        h = shape[2]
                        w = shape[3]
                    } else {
                        h = shape[1]
                        w = shape[2]
                    }
                }
            }
        }

        vnModel = vn
        fallbackModel = fallback
        fallbackInputName = inName
        fallbackOutputName = outName
        fallbackInputHeight = h
        fallbackInputWidth = w
        fallbackInputIsNCHW = isNCHW
    }

    var isModelAvailable: Bool { vnModel != nil || fallbackModel != nil }

    func embedding(from image: UIImage) -> [Float]? {
        guard let cgImage = image.cgImage else { return nil }
        if let vnModel { return embeddingViaVision(cgImage: cgImage, vnModel: vnModel) }
        if let fallbackModel, let inName = fallbackInputName, let outName = fallbackOutputName {
            return embeddingViaFallback(cgImage: cgImage, model: fallbackModel, inputName: inName, outputName: outName)
        }
        return nil
    }

    func embedding(from pixelBuffer: CVPixelBuffer, boundingBox: CGRect) -> [Float]? {
        if let vnModel { return embeddingViaVision(pixelBuffer: pixelBuffer, boundingBox: boundingBox, vnModel: vnModel) }
        if let fallbackModel, let inName = fallbackInputName, let outName = fallbackOutputName {
            return embeddingViaFallback(pixelBuffer: pixelBuffer, boundingBox: boundingBox, model: fallbackModel, inputName: inName, outputName: outName)
        }
        return nil
    }

    // MARK: - Vision path

    private func embeddingViaVision(cgImage: CGImage, vnModel: VNCoreMLModel) -> [Float]? {
        let faceDetection = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do { try handler.perform([faceDetection]) } catch { return nil }
        guard let results = faceDetection.results,
              let mainFace = results.max(by: { a, b in
                  a.boundingBox.width * a.boundingBox.height < b.boundingBox.width * b.boundingBox.height
              }) else { return nil }
        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .scaleFill
        request.regionOfInterest = mainFace.boundingBox
        let embedHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do { try embedHandler.perform([request]) } catch { return nil }
        guard let result = request.results?.first as? VNCoreMLFeatureValueObservation,
              let array = result.featureValue.multiArrayValue else { return nil }
        return array.toFloatArray()
    }

    private func embeddingViaVision(pixelBuffer: CVPixelBuffer, boundingBox: CGRect, vnModel: VNCoreMLModel) -> [Float]? {
        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .scaleFill
        request.regionOfInterest = boundingBox
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])
        do { try handler.perform([request]) } catch { return nil }
        guard let result = request.results?.first as? VNCoreMLFeatureValueObservation,
              let array = result.featureValue.multiArrayValue else { return nil }
        return array.toFloatArray()
    }

    // MARK: - Fallback path (multiarray input)

    private func embeddingViaFallback(cgImage: CGImage, model: MLModel, inputName: String, outputName: String) -> [Float]? {
        let faceDetection = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do { try handler.perform([faceDetection]) } catch { return nil }
        guard let results = faceDetection.results,
              let mainFace = results.max(by: { a, b in
                  a.boundingBox.width * a.boundingBox.height < b.boundingBox.width * b.boundingBox.height
              }) else { return nil }
        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        let roi = visionNormToImageRect(mainFace.boundingBox, imageWidth: imgW, imageHeight: imgH)
        guard let cropped = cgImage.cropping(to: roi) else { return nil }
        guard let inputArray = makeFaceInputArray(cgImage: cropped, height: fallbackInputHeight, width: fallbackInputWidth, isNCHW: fallbackInputIsNCHW) else { return nil }
        return runFallbackPrediction(model: model, inputName: inputName, outputName: outputName, inputArray: inputArray)
    }

    private func embeddingViaFallback(pixelBuffer: CVPixelBuffer, boundingBox: CGRect, model: MLModel, inputName: String, outputName: String) -> [Float]? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let roi = visionNormToImageRect(boundingBox, imageWidth: CGFloat(width), imageHeight: CGFloat(height))
        guard let croppedCG = createCGImage(from: pixelBuffer, cropRect: roi) else { return nil }
        guard let inputArray = makeFaceInputArray(cgImage: croppedCG, height: fallbackInputHeight, width: fallbackInputWidth, isNCHW: fallbackInputIsNCHW) else { return nil }
        return runFallbackPrediction(model: model, inputName: inputName, outputName: outputName, inputArray: inputArray)
    }

    private func runFallbackPrediction(model: MLModel, inputName: String, outputName: String, inputArray: MLMultiArray) -> [Float]? {
        let input = [inputName: MLFeatureValue(multiArray: inputArray)]
        guard let provider = try? MLDictionaryFeatureProvider(dictionary: input),
              let out = try? model.prediction(from: provider).featureValue(for: outputName),
              let array = out.multiArrayValue else { return nil }
        return array.toFloatArray()
    }

    /// Vision normalized rect (0–1, origin bottom-left) → image pixel rect.
    private func visionNormToImageRect(_ r: CGRect, imageWidth: CGFloat, imageHeight: CGFloat) -> CGRect {
        let x = r.minX * imageWidth
        let y = imageHeight - (r.minY + r.height) * imageHeight
        let w = r.width * imageWidth
        let h = r.height * imageHeight
        let xx = max(0, min(x, imageWidth - 1))
        let yy = max(0, min(y, imageHeight - 1))
        let ww = min(w, imageWidth - xx)
        let hh = min(h, imageHeight - yy)
        return CGRect(x: xx, y: yy, width: max(1, ww), height: max(1, hh))
    }

    /// Resize CGImage to height×width and fill MLMultiArray (NHWC or NCHW), values in [0,1].
    private func makeFaceInputArray(cgImage: CGImage, height: Int, width: Int, isNCHW: Bool) -> MLMultiArray? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = ctx.data else { return nil }
        let ptr = data.assumingMemoryBound(to: UInt8.self)

        let array: MLMultiArray?
        if isNCHW {
            array = try? MLMultiArray(shape: [1, 3, height, width], dataType: .float32)
            guard let arr = array else { return nil }
            for y in 0..<height {
                for x in 0..<width {
                    let offset = (y * width + x) * 4
                    let r = Float(ptr[offset]) / 255.0
                    let g = Float(ptr[offset + 1]) / 255.0
                    let b = Float(ptr[offset + 2]) / 255.0
                    arr[[0, 0, y, x].map { NSNumber(value: $0) }] = NSNumber(value: r)
                    arr[[0, 1, y, x].map { NSNumber(value: $0) }] = NSNumber(value: g)
                    arr[[0, 2, y, x].map { NSNumber(value: $0) }] = NSNumber(value: b)
                }
            }
        } else {
            array = try? MLMultiArray(shape: [1, height, width, 3], dataType: .float32)
            guard let arr = array else { return nil }
            for y in 0..<height {
                for x in 0..<width {
                    let offset = (y * width + x) * 4
                    let r = Float(ptr[offset]) / 255.0
                    let g = Float(ptr[offset + 1]) / 255.0
                    let b = Float(ptr[offset + 2]) / 255.0
                    arr[[0, y, x, 0].map { NSNumber(value: $0) }] = NSNumber(value: r)
                    arr[[0, y, x, 1].map { NSNumber(value: $0) }] = NSNumber(value: g)
                    arr[[0, y, x, 2].map { NSNumber(value: $0) }] = NSNumber(value: b)
                }
            }
        }
        return array
    }

    /// Crop CVPixelBuffer to rect (pixel coordinates) and return as CGImage.
    private func createCGImage(from pixelBuffer: CVPixelBuffer, cropRect: CGRect) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let cropped = ciImage.cropped(to: cropRect)
        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        return ctx.createCGImage(cropped, from: cropped.extent)
    }
}

private extension MLMultiArray {
    func toFloatArray() -> [Float] {
        (0..<count).map { self[$0].floatValue }
    }
}
