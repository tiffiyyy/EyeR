//
//  ConversationRecord.swift
//  GlimpseH4H
//

import Foundation

struct ConversationRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var personId: UUID
    var startedAt: Date
    var endedAt: Date
    var transcript: String
    var summary: String

    init(
        id: UUID = UUID(),
        personId: UUID,
        startedAt: Date,
        endedAt: Date,
        transcript: String,
        summary: String
    ) {
        self.id = id
        self.personId = personId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.transcript = transcript
        self.summary = summary
    }
}
