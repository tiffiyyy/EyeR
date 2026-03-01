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
    var embeddingData: [Data]  // facial embedding blobs from 4–5 photos
    var createdAt: Date
    var lastSeenAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        relationship: String,
        conversationSummary: String = "",
        embeddingData: [Data] = [],
        createdAt: Date = Date(),
        lastSeenAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.conversationSummary = conversationSummary
        self.embeddingData = embeddingData
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
    }
}
