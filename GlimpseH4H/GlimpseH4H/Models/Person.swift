//
//  Person.swift
//  GlimpseH4H
//

import Foundation

struct Person: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var relationship: String
    var conversationSummary: String
    /// JPEG image data for this person's reference photos (used in onboarding UI).
    var embeddingData: [Data]
    /// Face embedding vectors (one per onboarding photo) used for recognition.
    var faceEmbeddings: [[Float]]
    var createdAt: Date
    var lastSeenAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        relationship: String,
        conversationSummary: String = "",
        embeddingData: [Data] = [],
        faceEmbeddings: [[Float]] = [],
        createdAt: Date = Date(),
        lastSeenAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.conversationSummary = conversationSummary
        self.embeddingData = embeddingData
        self.faceEmbeddings = faceEmbeddings
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
    }
}

