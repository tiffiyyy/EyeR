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
    /// Legacy field from older builds that stored enrollment photos directly.
    var embeddingData: [Data]
    /// Canonical enrollment photos retained for editing/re-enrollment.
    var enrollmentImageData: [Data]
    /// L2-normalized embedding vector used for runtime matching.
    var faceEmbedding: [Float]
    var createdAt: Date
    var lastSeenAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        relationship: String,
        conversationSummary: String = "",
        embeddingData: [Data] = [],
        enrollmentImageData: [Data] = [],
        faceEmbedding: [Float] = [],
        createdAt: Date = Date(),
        lastSeenAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.conversationSummary = conversationSummary
        self.embeddingData = embeddingData
        self.enrollmentImageData = enrollmentImageData
        self.faceEmbedding = faceEmbedding
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
    }
}

extension Person {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case relationship
        case conversationSummary
        case embeddingData
        case enrollmentImageData
        case faceEmbedding
        case createdAt
        case lastSeenAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        relationship = try container.decode(String.self, forKey: .relationship)
        conversationSummary = try container.decodeIfPresent(String.self, forKey: .conversationSummary) ?? ""
        embeddingData = try container.decodeIfPresent([Data].self, forKey: .embeddingData) ?? []
        enrollmentImageData = try container.decodeIfPresent([Data].self, forKey: .enrollmentImageData) ?? embeddingData
        faceEmbedding = try container.decodeIfPresent([Float].self, forKey: .faceEmbedding) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        lastSeenAt = try container.decodeIfPresent(Date.self, forKey: .lastSeenAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(relationship, forKey: .relationship)
        try container.encode(conversationSummary, forKey: .conversationSummary)
        try container.encode(embeddingData, forKey: .embeddingData)
        try container.encode(enrollmentImageData, forKey: .enrollmentImageData)
        try container.encode(faceEmbedding, forKey: .faceEmbedding)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(lastSeenAt, forKey: .lastSeenAt)
    }
}
