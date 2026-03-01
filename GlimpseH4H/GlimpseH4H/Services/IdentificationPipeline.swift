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
    /// Converts to view rect. Pass expansion (e.g. FaceCropper.faceCropExpansion) so the drawn rect matches the crop used for recognition.
    func boundingBox(in size: CGSize, expansion: CGFloat = 0) -> CGRect {
        var r = boundingBox
        if expansion > 0 {
            let ex = r.width * expansion
            let ey = r.height * expansion
            r = CGRect(x: r.minX - ex, y: r.minY - ey, width: r.width + 2 * ex, height: r.height + 2 * ey)
            r = r.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
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
    private let embeddingThrottleInterval: TimeInterval = 1.0
    private var lastEmbeddingTime: Date?
    private let matchThreshold: Float = FaceMatcher.defaultThreshold
    private let minFaceConfidence: Float = 0.4
    private let minNormalizedFaceSize: CGFloat = 0.08
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
            let valid = results.filter { obs in
                obs.confidence >= minFaceConfidence
                    && obs.boundingBox.width >= minNormalizedFaceSize
                    && obs.boundingBox.height >= minNormalizedFaceSize
            }
            let sorted = valid.sorted { lhs, rhs in
                (lhs.boundingBox.width * lhs.boundingBox.height) > (rhs.boundingBox.width * rhs.boundingBox.height)
            }
            let boxes = sorted.map { FaceOutline(boundingBox: $0.boundingBox) }
            var faceCrop: CGImage?
            var primaryFace: FaceOutline?
            if let largest = sorted.first {
                primaryFace = boxes.first
                if let frameImage = FaceCropper.makeOrientedCGImage(from: pixelBuffer, orientation: .leftMirrored) {
                    faceCrop = FaceCropper.cropFace(from: frameImage, boundingBox: largest.boundingBox, expansion: FaceCropper.faceCropExpansion)
                }
            }
            queue.async { [weak self] in
                self?.handleFaceResults(boxes: boxes, at: now, faceCrop: faceCrop, primaryFace: primaryFace)
            }
        } catch {}
    }

    private func handleFaceResults(boxes: [FaceOutline], at now: Date, faceCrop: CGImage?, primaryFace: FaceOutline?) {
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
           now.timeIntervalSince(lastEmbeddingTime ?? .distantPast) >= embeddingThrottleInterval,
           let faceCrop = faceCrop,
           let primaryFace = primaryFace {
            lastEmbeddingTime = now
            identifyCurrentFaceAndShowCard(faceCrop: faceCrop, primaryFace: primaryFace)
        }
    }

    private func identifyCurrentFaceAndShowCard(faceCrop: CGImage, primaryFace: FaceOutline) {
        guard let dataStore = dataStore else { return }
        let candidates = dataStore.people.compactMap { person -> (UUID, [Float])? in
            guard !person.faceEmbedding.isEmpty else { return nil }
            return (person.id, person.faceEmbedding)
        }
        guard !candidates.isEmpty else {
            #if DEBUG
            print("[FaceRec] no candidates (people with embeddings)")
            #endif
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let probeEmbedding: [Float]
            do {
                probeEmbedding = try FaceEmbedder.shared.embedding(from: faceCrop)
            } catch {
                #if DEBUG
                print("[FaceRec] embedding failed: \(error.localizedDescription)")
                #endif
                return
            }

            let (matchId, bestScore) = FaceMatcher.bestMatchWithScore(
                probeEmbedding: probeEmbedding,
                candidates: candidates,
                threshold: matchThreshold
            )
            #if DEBUG
            let personName = matchId.flatMap { id in dataStore.people.first(where: { $0.id == id })?.name }
            print("[FaceRec] bestScore=\(String(format: "%.3f", bestScore)) threshold=\(matchThreshold) → \(matchId != nil ? "MATCH: \(personName ?? "?")" : "no match")")
            #endif
            self.lastIdentifiedPersonId = matchId
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let id = matchId {
                    self.currentlyIdentifiedPerson = IdentifiedPerson(personId: id)
                    dataStore.updateLastSeen(personId: id, at: Date())
                } else {
                    self.currentlyIdentifiedPerson = nil
                }
            }
        }
    }
}
