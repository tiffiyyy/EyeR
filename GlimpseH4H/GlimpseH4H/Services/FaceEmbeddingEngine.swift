//
//  FaceEmbeddingEngine.swift
//  GlimpseH4H
//
//

import CoreGraphics
import Foundation
import UIKit

#if canImport(TensorFlowLite)
import TensorFlowLite
#endif

enum FaceEmbeddingError: LocalizedError {
    case tfliteNotLinked
    case modelNotFound
    case interpreterInitFailed
    case invalidInputShape
    case unsupportedInputType
    case unsupportedOutputType
    case imagePreprocessFailed
    case noValidEnrollmentFaces
    case insufficientValidEnrollmentFaces

    var errorDescription: String? {
        switch self {
        case .tfliteNotLinked:
            return "TensorFlowLite framework is not linked to the iOS target."
        case .modelNotFound:
            return "Could not locate mobilefacenet.tflite in app bundle resources."
        case .interpreterInitFailed:
            return "Failed to initialize TensorFlow Lite interpreter."
        case .invalidInputShape:
            return "Model input tensor shape is not supported."
        case .unsupportedInputType:
            return "Model input tensor type is not supported."
        case .unsupportedOutputType:
            return "Model output tensor type is not supported."
        case .imagePreprocessFailed:
            return "Failed to preprocess face crop into model input tensor."
        case .noValidEnrollmentFaces:
            return "No valid faces were detected from enrollment photos."
        case .insufficientValidEnrollmentFaces:
            return "Not enough valid face crops were found. Capture clearer front-facing photos."
        }
    }
}

#if canImport(TensorFlowLite)
final class FaceModelLoader {
    static let shared = FaceModelLoader()

    private(set) var interpreter: Interpreter?
    private(set) var inputWidth: Int = 0
    private(set) var inputHeight: Int = 0
    private(set) var inputChannels: Int = 0
    private(set) var inputDataType: Tensor.DataType = .float32
    private(set) var isNCHW: Bool = false
    private var didLogTensorMetadata = false

    private init() {}

    func loadIfNeeded() throws -> Interpreter {
        if let interpreter {
            return interpreter
        }

        guard let modelURL = Self.modelURL() else {
            throw FaceEmbeddingError.modelNotFound
        }

        var options = Interpreter.Options()
        options.threadCount = 2

        do {
            let newInterpreter = try Interpreter(modelPath: modelURL.path, options: options)
            try newInterpreter.allocateTensors()
            let input = try newInterpreter.input(at: 0)

            let dims = input.shape.dimensions
            guard dims.count == 4 else { throw FaceEmbeddingError.invalidInputShape }
            if dims[3] == 3 {
                // NHWC
                isNCHW = false
                inputHeight = dims[1]
                inputWidth = dims[2]
                inputChannels = dims[3]
            } else if dims[1] == 3 {
                // NCHW
                isNCHW = true
                inputChannels = dims[1]
                inputHeight = dims[2]
                inputWidth = dims[3]
            } else {
                throw FaceEmbeddingError.invalidInputShape
            }

            inputDataType = input.dataType
            interpreter = newInterpreter

            if !didLogTensorMetadata {
                let output = try newInterpreter.output(at: 0)
                print("Face model loaded: \(modelURL.lastPathComponent)")
                print("Input tensor: shape=\(dims), type=\(input.dataType)")
                print("Output tensor: shape=\(output.shape.dimensions), type=\(output.dataType)")
                didLogTensorMetadata = true
            }
            return newInterpreter
        } catch {
            throw FaceEmbeddingError.interpreterInitFailed
        }
    }

    private static func modelURL() -> URL? {
        let candidates: [(name: String, subdirectory: String?)] = [
            ("mobilefacenet", nil),
            ("mobilefacenet", "Resources/ML"),
            ("face_embedder", nil),
            ("face_embedder", "Resources/ML")
        ]

        for candidate in candidates {
            if let url = Bundle.main.url(
                forResource: candidate.name,
                withExtension: "tflite",
                subdirectory: candidate.subdirectory
            ) {
                return url
            }
        }
        return nil
    }
}

enum FacePreprocessor {
    static func makeInputTensorData(
        from faceCrop: CGImage,
        width: Int,
        height: Int,
        channels: Int,
        dataType: Tensor.DataType,
        isNCHW: Bool
    ) throws -> Data {
        guard channels == 3 else { throw FaceEmbeddingError.invalidInputShape }
        let rgbaBytes = try resizedRGBABytes(from: faceCrop, width: width, height: height)

        switch dataType {
        case .float32:
            return makeFloat32InputData(rgbaBytes: rgbaBytes, width: width, height: height, isNCHW: isNCHW)
        case .uInt8:
            return makeUInt8InputData(rgbaBytes: rgbaBytes, width: width, height: height, isNCHW: isNCHW)
        default:
            throw FaceEmbeddingError.unsupportedInputType
        }
    }

    private static func resizedRGBABytes(from image: CGImage, width: Int, height: Int) throws -> [UInt8] {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var bytes = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: &bytes,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw FaceEmbeddingError.imagePreprocessFailed
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }

    private static func makeFloat32InputData(rgbaBytes: [UInt8], width: Int, height: Int, isNCHW: Bool) -> Data {
        // MobileFaceNet commonly expects [-1, 1] via (x - 127.5) / 128
        @inline(__always)
        func norm(_ byte: UInt8) -> Float {
            (Float(byte) - 127.5) / 128.0
        }

        if isNCHW {
            var floats = [Float](repeating: 0, count: width * height * 3)
            let hw = width * height
            for y in 0..<height {
                for x in 0..<width {
                    let pixelIndex = (y * width + x) * 4
                    let i = y * width + x
                    floats[i] = norm(rgbaBytes[pixelIndex]) // R
                    floats[hw + i] = norm(rgbaBytes[pixelIndex + 1]) // G
                    floats[(2 * hw) + i] = norm(rgbaBytes[pixelIndex + 2]) // B
                }
            }
            return Data(copyingBufferOf: floats)
        } else {
            var floats = [Float](repeating: 0, count: width * height * 3)
            var out = 0
            for y in 0..<height {
                for x in 0..<width {
                    let pixelIndex = (y * width + x) * 4
                    floats[out] = norm(rgbaBytes[pixelIndex]); out += 1 // R
                    floats[out] = norm(rgbaBytes[pixelIndex + 1]); out += 1 // G
                    floats[out] = norm(rgbaBytes[pixelIndex + 2]); out += 1 // B
                }
            }
            return Data(copyingBufferOf: floats)
        }
    }

    private static func makeUInt8InputData(rgbaBytes: [UInt8], width: Int, height: Int, isNCHW: Bool) -> Data {
        if isNCHW {
            var values = [UInt8](repeating: 0, count: width * height * 3)
            let hw = width * height
            for y in 0..<height {
                for x in 0..<width {
                    let pixelIndex = (y * width + x) * 4
                    let i = y * width + x
                    values[i] = rgbaBytes[pixelIndex] // R
                    values[hw + i] = rgbaBytes[pixelIndex + 1] // G
                    values[(2 * hw) + i] = rgbaBytes[pixelIndex + 2] // B
                }
            }
            return Data(values)
        } else {
            var values = [UInt8](repeating: 0, count: width * height * 3)
            var out = 0
            for y in 0..<height {
                for x in 0..<width {
                    let pixelIndex = (y * width + x) * 4
                    values[out] = rgbaBytes[pixelIndex]; out += 1 // R
                    values[out] = rgbaBytes[pixelIndex + 1]; out += 1 // G
                    values[out] = rgbaBytes[pixelIndex + 2]; out += 1 // B
                }
            }
            return Data(values)
        }
    }
}

final class FaceEmbedder {
    static let shared = FaceEmbedder()

    private init() {}

    func embedding(from faceCrop: CGImage) throws -> [Float] {
        let loader = FaceModelLoader.shared
        let interpreter = try loader.loadIfNeeded()
        let inputData = try FacePreprocessor.makeInputTensorData(
            from: faceCrop,
            width: loader.inputWidth,
            height: loader.inputHeight,
            channels: loader.inputChannels,
            dataType: loader.inputDataType,
            isNCHW: loader.isNCHW
        )

        try interpreter.copy(inputData, toInputAt: 0)
        try interpreter.invoke()

        let output = try interpreter.output(at: 0)
        let embedding = try decodeOutput(output)
        return FaceMatcher.l2Normalize(embedding)
    }

    private func decodeOutput(_ tensor: Tensor) throws -> [Float] {
        switch tensor.dataType {
        case .float32:
            return tensor.data.toArray(type: Float.self)
        case .uInt8:
            let values = tensor.data.toArray(type: UInt8.self)
            let scale = tensor.quantizationParameters?.scale ?? 1
            let zeroPoint = Float(tensor.quantizationParameters?.zeroPoint ?? 0)
            return values.map { (Float($0) - zeroPoint) * scale }
        default:
            throw FaceEmbeddingError.unsupportedOutputType
        }
    }
}

final class FaceEnrollmentService {
    static let shared = FaceEnrollmentService()
    private let minimumValidFaces = 2

    private init() {}

    func enroll(from images: [UIImage]) throws -> (embedding: [Float], keptImages: [Data]) {
        var embeddings: [[Float]] = []
        var keptImages: [Data] = []

        for image in images {
            guard let face = FaceCropper.cropLargestFace(from: image) else { continue }
            guard let data = image.jpegData(compressionQuality: 0.8) else { continue }
            let embedding = try FaceEmbedder.shared.embedding(from: face)
            embeddings.append(embedding)
            keptImages.append(data)
        }

        guard !embeddings.isEmpty else {
            throw FaceEmbeddingError.noValidEnrollmentFaces
        }
        guard embeddings.count >= minimumValidFaces else {
            throw FaceEmbeddingError.insufficientValidEnrollmentFaces
        }

        let length = embeddings[0].count
        var average = [Float](repeating: 0, count: length)
        for emb in embeddings where emb.count == length {
            for i in 0..<length {
                average[i] += emb[i]
            }
        }
        let denom = Float(embeddings.count)
        for i in 0..<length {
            average[i] /= denom
        }
        return (FaceMatcher.l2Normalize(average), keptImages)
    }
}

#else
final class FaceModelLoader {
    static let shared = FaceModelLoader()
    private init() {}

    func loadIfNeeded() throws {
        throw FaceEmbeddingError.tfliteNotLinked
    }
}

final class FaceEmbedder {
    static let shared = FaceEmbedder()
    private init() {}

    func embedding(from faceCrop: CGImage) throws -> [Float] {
        throw FaceEmbeddingError.tfliteNotLinked
    }
}

final class FaceEnrollmentService {
    static let shared = FaceEnrollmentService()
    private init() {}

    func enroll(from images: [UIImage]) throws -> (embedding: [Float], keptImages: [Data]) {
        throw FaceEmbeddingError.tfliteNotLinked
    }
}
#endif

private extension Data {
    init<T>(copyingBufferOf values: [T]) {
        self = values.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    func toArray<T>(type: T.Type) -> [T] {
        let count = self.count / MemoryLayout<T>.stride
        return withUnsafeBytes { bytes in
            let ptr = bytes.bindMemory(to: T.self).baseAddress!
            return Array(UnsafeBufferPointer(start: ptr, count: count))
        }
    }
}
