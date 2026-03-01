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
    /// Relative paths to enrollment photos in ImageStore (used for edit UI). Not stored in UserDefaults as raw Data.
    var photoPaths: [String]
    /// L2-normalized embedding vector used for runtime matching.
    var faceEmbedding: [Float]
    var createdAt: Date
    var lastSeenAt: Date?

    /// Filled only when decoding legacy payloads that had enrollmentImageData/embeddingData. Cleared after migration in DataStore. Not encoded.
    var legacyPhotoDataForMigration: [Data]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case relationship
        case conversationSummary
        case photoPaths
        case faceEmbedding
        case createdAt
        case lastSeenAt
        case embeddingData
        case enrollmentImageData
    }

    init(
        id: UUID = UUID(),
        name: String,
        relationship: String,
        conversationSummary: String = "",
        photoPaths: [String] = [],
        faceEmbedding: [Float] = [],
        createdAt: Date = Date(),
        lastSeenAt: Date? = nil,
        legacyPhotoDataForMigration: [Data]? = nil
    ) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.conversationSummary = conversationSummary
        self.photoPaths = photoPaths
        self.faceEmbedding = faceEmbedding
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
        self.legacyPhotoDataForMigration = legacyPhotoDataForMigration
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        relationship = try c.decode(String.self, forKey: .relationship)
        conversationSummary = try c.decodeIfPresent(String.self, forKey: .conversationSummary) ?? ""
        faceEmbedding = try c.decodeIfPresent([Float].self, forKey: .faceEmbedding) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        lastSeenAt = try c.decodeIfPresent(Date.self, forKey: .lastSeenAt)
        photoPaths = try c.decodeIfPresent([String].self, forKey: .photoPaths) ?? []
        let enrollmentData = try c.decodeIfPresent([Data].self, forKey: .enrollmentImageData)
        let embeddingData = try c.decodeIfPresent([Data].self, forKey: .embeddingData)
        let legacy = enrollmentData ?? embeddingData
        legacyPhotoDataForMigration = (!photoPaths.isEmpty || legacy == nil || legacy?.isEmpty == true) ? nil : legacy
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(relationship, forKey: .relationship)
        try c.encode(conversationSummary, forKey: .conversationSummary)
        try c.encode(photoPaths, forKey: .photoPaths)
        try c.encode(faceEmbedding, forKey: .faceEmbedding)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(lastSeenAt, forKey: .lastSeenAt)
    }
}
