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
    /// Cosine similarity (0–1) of the last successful face match; nil when no one is identified.
    @Published private(set) var lastMatchScore: Float?
    /// Set when room recognition identifies a room; used for the compact room-name banner.
    @Published var currentRoomName: String?

    private var faceDetectionRequest: VNDetectFaceRectanglesRequest?
    private var firstFaceSeenAt: Date?
    private var lastFaceSeenTime: Date?
    private var lastIdentifiedPersonId: UUID?
    private let faceStableDuration: TimeInterval = 2.0
    private let personLeftDuration: TimeInterval = 5.0
    /// How often to re-run recognition for a locked-in person.
    private let recognitionInterval: TimeInterval = 5.0
    /// Minimum similarity score (cosine) for a match to be considered valid.
    private let matchThreshold: Float = 0.82
    /// Best match must be at least this much higher than second-best to avoid ambiguous wrong matches.
    private let matchMargin: Float = 0.06
    private var lastRecognitionTime: Date?
    private var dataStore: DataStore?
    private var isRunning = false
    private let queue = DispatchQueue(label: "pipeline.queue")

    private init() {}

    func start(dataStore: DataStore) {
        self.dataStore = dataStore
        isRunning = true
        faceDetectionRequest = VNDetectFaceRectanglesRequest()
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
                self?.handleFaceResults(pixelBuffer: pixelBuffer, boxes: boxes, at: now)
            }
        } catch {}
    }

    private func handleFaceResults(pixelBuffer: CVPixelBuffer, boxes: [FaceOutline], at now: Date) {
        let hadFace = !boxes.isEmpty
        if hadFace {
            if firstFaceSeenAt == nil { firstFaceSeenAt = now }
            lastFaceSeenTime = now
        } else {
            firstFaceSeenAt = nil
            if let last = lastFaceSeenTime, now.timeIntervalSince(last) >= personLeftDuration {
                lastIdentifiedPersonId = nil
                lastRecognitionTime = nil
                lastFaceSeenTime = nil
                DispatchQueue.main.async { [weak self] in
                    self?.currentlyIdentifiedPerson = nil
                    self?.lastMatchScore = nil
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.visibleFaceOutlines = boxes
        }

        guard hadFace else { return }

        // No one currently locked in: wait until a face has been stable for `faceStableDuration`,
        // then attempt to recognize against stored embeddings.
        if lastIdentifiedPersonId == nil,
           let first = firstFaceSeenAt,
           now.timeIntervalSince(first) >= faceStableDuration {
            // Avoid hammering recognition if multiple frames cross the stability threshold.
            if let lastCheck = lastRecognitionTime,
               now.timeIntervalSince(lastCheck) < faceStableDuration / 2 {
                return
            }
            lastRecognitionTime = now
            runRecognition(on: pixelBuffer, boxes: boxes, now: now, expectedPersonId: nil)
            return
        }

        // Someone is already locked in: every `recognitionInterval` seconds, re-run recognition
        // to confirm they are still the main figure in frame. If not, clear and fall back to
        // the stable-face detection flow.
        if let lockedId = lastIdentifiedPersonId {
            if let lastCheck = lastRecognitionTime,
               now.timeIntervalSince(lastCheck) < recognitionInterval {
                return
            }
            lastRecognitionTime = now
            runRecognition(on: pixelBuffer, boxes: boxes, now: now, expectedPersonId: lockedId)
        }
    }

    private func runRecognition(on pixelBuffer: CVPixelBuffer, boxes: [FaceOutline], now: Date, expectedPersonId: UUID?) {
        guard let dataStore = dataStore, !dataStore.people.isEmpty else { return }

        // Choose the largest face as the "main" figure in frame.
        guard let mainFace = boxes.max(by: { a, b in
            let areaA = a.boundingBox.width * a.boundingBox.height
            let areaB = b.boundingBox.width * b.boundingBox.height
            return areaA < areaB
        }) else {
            return
        }

        // Generate an embedding for the current face.
        guard let currentEmbedding = FaceEmbeddingService.shared.embedding(
            from: pixelBuffer,
            boundingBox: mainFace.boundingBox
        ) else {
            // If we previously had someone locked in but can no longer get an embedding,
            // treat this as losing track and reset to detection mode.
            if expectedPersonId != nil {
                lastIdentifiedPersonId = nil
                DispatchQueue.main.async { [weak self] in
                    self?.currentlyIdentifiedPerson = nil
                }
            }
            return
        }

        // Compare against all stored embeddings for all people.
        var bestMatchId: UUID?
        var bestScore: Float = -1
        var secondBestScore: Float = -1

        for person in dataStore.people {
            for embedding in person.faceEmbeddings {
                guard embedding.count == currentEmbedding.count, !embedding.isEmpty else { continue }
                let score = cosineSimilarity(currentEmbedding, embedding)
                if score > bestScore {
                    secondBestScore = bestScore
                    bestScore = score
                    bestMatchId = person.id
                } else if score > secondBestScore {
                    secondBestScore = score
                }
            }
        }

        let marginOk = (secondBestScore < 0) || (bestScore - secondBestScore >= matchMargin)
        guard let matchId = bestMatchId, bestScore >= matchThreshold, marginOk else {
            // No valid match: if we had an expected person, clear and fall back to detection.
            if expectedPersonId != nil {
                lastIdentifiedPersonId = nil
                DispatchQueue.main.async { [weak self] in
                    self?.currentlyIdentifiedPerson = nil
                    self?.lastMatchScore = nil
                }
            }
            return
        }

        // If we were re-validating a locked-in person and the best match is *not* them,
        // treat this as the original person leaving; clear and let the stable detection
        // flow decide when to recognize the new person.
        if let expected = expectedPersonId, expected != matchId {
            lastIdentifiedPersonId = nil
            DispatchQueue.main.async { [weak self] in
                self?.currentlyIdentifiedPerson = nil
                self?.lastMatchScore = nil
            }
            return
        }

        // At this point, we either have:
        // - An initial recognition (expectedPersonId == nil), or
        // - A re-validation that confirms the same person is still present.
        lastIdentifiedPersonId = matchId
        let scoreToPublish = bestScore
        DispatchQueue.main.async { [weak self] in
            self?.currentlyIdentifiedPerson = IdentifiedPerson(personId: matchId)
            self?.lastMatchScore = scoreToPublish
            self?.dataStore?.updateLastSeen(personId: matchId, at: now)
        }
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return -1 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for i in 0..<a.count {
            let x = a[i]
            let y = b[i]
            dot += x * y
            normA += x * x
            normB += y * y
        }
        let denom = (normA.squareRoot() * normB.squareRoot())
        guard denom > 0 else { return -1 }
        return dot / denom
    }
}

