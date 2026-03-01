//
//  FaceMatcher.swift
//  GlimpseH4H
//
//

import Foundation

enum FaceMatcher {
    /// MobileFaceNet-style cosine threshold. Tune with real enrollment/live samples.
    static let defaultThreshold: Float = 0.55

    static func l2Normalize(_ vector: [Float]) -> [Float] {
        let sumSquares = vector.reduce(0) { $0 + $1 * $1 }
        guard sumSquares > 0 else { return vector }
        let magnitude = sqrt(sumSquares)
        return vector.map { $0 / magnitude }
    }

    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return -1 }
        var dot: Float = 0
        for i in a.indices {
            dot += a[i] * b[i]
        }
        return dot
    }

    static func bestMatch(
        probeEmbedding: [Float],
        candidates: [(personId: UUID, embedding: [Float])],
        threshold: Float = defaultThreshold
    ) -> UUID? {
        guard !candidates.isEmpty else { return nil }
        let normalizedProbe = l2Normalize(probeEmbedding)

        var bestId: UUID?
        var bestScore: Float = -1
        for candidate in candidates {
            let score = cosineSimilarity(normalizedProbe, l2Normalize(candidate.embedding))
            if score > bestScore {
                bestScore = score
                bestId = candidate.personId
            }
        }
        guard bestScore >= threshold else { return nil }
        return bestId
    }
}
