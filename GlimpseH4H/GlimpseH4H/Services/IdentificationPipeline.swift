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
            x: r.minX * size.width,
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
    private var dataStore: DataStore?
    private var isRunning = false
    private let queue = DispatchQueue(label: "pipeline.queue")

    /// True when identification is paused (show Resume in UI); false when running (show Pause).
    @Published private(set) var isPaused: Bool = true

    private init() {}

    func start(dataStore: DataStore) {
        self.dataStore = dataStore
        isRunning = true
        faceDetectionRequest = VNDetectFaceRectanglesRequest()
        DispatchQueue.main.async { [weak self] in
            self?.isPaused = false
        }
    }

    func pause() {
        isRunning = false
        DispatchQueue.main.async { [weak self] in
            self?.isPaused = true
            self?.visibleFaceOutlines = []
            self?.currentlyIdentifiedPerson = nil
        }
    }

    /// Resume identification after pause (uses existing dataStore reference).
    func resume() {
        guard let dataStore else { return }
        start(dataStore: dataStore)
    }

    func processFrame(_ sampleBuffer: CMSampleBuffer, cameraPosition: AVCaptureDevice.Position) {
        guard isRunning else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = faceDetectionRequest ?? VNDetectFaceRectanglesRequest()
        let orientation: CGImagePropertyOrientation = cameraPosition == .front ? .leftMirrored : .right
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
            guard let results = request.results else { return }
            let now = Date()
            let boxes = results.map { FaceOutline(boundingBox: $0.boundingBox) }
            queue.async { [weak self] in
                self?.handleFaceResults(boxes: boxes, at: now)
            }
        } catch {}
    }

    private func handleFaceResults(boxes: [FaceOutline], at now: Date) {
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

        if hadFace, let first = firstFaceSeenAt, now.timeIntervalSince(first) >= faceStableDuration, lastIdentifiedPersonId == nil {
            identifyCurrentFaceAndShowCard()
        }
    }

    private func identifyCurrentFaceAndShowCard() {
        guard let dataStore = dataStore, !dataStore.people.isEmpty else { return }
        let matchId = dataStore.people.first?.id
        lastIdentifiedPersonId = matchId
        if let id = matchId {
            DispatchQueue.main.async { [weak self] in
                self?.currentlyIdentifiedPerson = IdentifiedPerson(personId: id)
            }
            dataStore.updateLastSeen(personId: id, at: Date())
        }
    }
}
