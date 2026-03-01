//
//  IdentificationPipeline.swift
//  GlimpseH4H
//

import AVFoundation
import Combine
import UIKit
import Vision

struct FaceOutline: Identifiable {
    let id = UUID()
    var boundingBox: CGRect  // normalized 0–1, origin bottom-left (Vision)
    func boundingBox(in size: CGSize) -> CGRect {
        let r = boundingBox
        return CGRect(
            x: size.width - (r.minX + r.width) * size.width,
            y: size.height - (r.minY + r.height) * size.height,
            width: r.width * size.width,
            height: r.height * size.height
        )
    }
}

struct IdentifiedPerson {
    let personId: UUID
}

final class IdentificationPipeline: ObservableObject {
    static let shared = IdentificationPipeline()

    @Published private(set) var visibleFaceOutlines: [FaceOutline] = []
    @Published private(set) var currentlyIdentifiedPerson: IdentifiedPerson?
    /// Set when room recognition identifies a room; used for the compact room-name banner.
    @Published var currentRoomName: String?

    private var faceDetectionRequest: VNDetectFaceRectanglesRequest?
    private var firstFaceSeenAt: Date?
    private var lastFaceSeenTime: Date?
    private var lastIdentifiedPersonId: UUID?
    private let faceStableDuration: TimeInterval = 2.0
    private let personLeftDuration: TimeInterval = 5.0
    private let matchThreshold: Float = FaceMatcher.defaultThreshold
    private var dataStore: DataStore?
    private var isRunning = false
    private let queue = DispatchQueue(label: "pipeline.queue")

    private init() {}

    func start(dataStore: DataStore) {
        self.dataStore = dataStore
        isRunning = true
        faceDetectionRequest = VNDetectFaceRectanglesRequest()
        _ = try? FaceModelLoader.shared.loadIfNeeded()
    }

    func pause() {
        isRunning = false
        DispatchQueue.main.async { [weak self] in
            self?.visibleFaceOutlines = []
            self?.currentlyIdentifiedPerson = nil
        }
    }

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isRunning else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = faceDetectionRequest ?? VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])
        do {
            try handler.perform([request])
            guard let results = request.results else { return }
            let now = Date()
            let boxes = results.map { FaceOutline(boundingBox: $0.boundingBox) }
            queue.async { [weak self] in
                self?.handleFaceResults(boxes: boxes, at: now, pixelBuffer: pixelBuffer)
            }
        } catch {}
    }

    private func handleFaceResults(boxes: [FaceOutline], at now: Date, pixelBuffer: CVPixelBuffer) {
        let hadFace = !boxes.isEmpty
        if hadFace {
            if firstFaceSeenAt == nil { firstFaceSeenAt = now }
            lastFaceSeenTime = now
        } else {
            firstFaceSeenAt = nil
            if let last = lastFaceSeenTime, now.timeIntervalSince(last) >= personLeftDuration {
                lastIdentifiedPersonId = nil
                lastFaceSeenTime = nil
                DispatchQueue.main.async { [weak self] in
                    self?.currentlyIdentifiedPerson = nil
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.visibleFaceOutlines = boxes
        }

        if hadFace,
           let first = firstFaceSeenAt,
           now.timeIntervalSince(first) >= faceStableDuration,
           lastIdentifiedPersonId == nil,
           let primaryFace = boxes.first {
            identifyCurrentFaceAndShowCard(pixelBuffer: pixelBuffer, face: primaryFace)
        }
    }

    private func identifyCurrentFaceAndShowCard(pixelBuffer: CVPixelBuffer, face: FaceOutline) {
        guard let dataStore = dataStore else { return }
        let candidates = dataStore.people.compactMap { person -> (UUID, [Float])? in
            guard !person.faceEmbedding.isEmpty else { return nil }
            return (person.id, person.faceEmbedding)
        }
        guard !candidates.isEmpty else { return }
        guard let frameImage = FaceCropper.makeOrientedCGImage(from: pixelBuffer, orientation: .leftMirrored) else { return }
        guard let faceCrop = FaceCropper.cropFace(from: frameImage, boundingBox: face.boundingBox) else { return }

        let probeEmbedding: [Float]
        do {
            probeEmbedding = try FaceEmbedder.shared.embedding(from: faceCrop)
        } catch {
            print("Face embedding failed: \(error.localizedDescription)")
            return
        }

        let matchId = FaceMatcher.bestMatch(
            probeEmbedding: probeEmbedding,
            candidates: candidates,
            threshold: matchThreshold
        )
        lastIdentifiedPersonId = matchId
        if let id = matchId {
            DispatchQueue.main.async { [weak self] in
                self?.currentlyIdentifiedPerson = IdentifiedPerson(personId: id)
            }
            dataStore.updateLastSeen(personId: id, at: Date())
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.currentlyIdentifiedPerson = nil
            }
        }
    }
}
