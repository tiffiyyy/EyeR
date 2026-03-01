//
//  Room.swift
//  GlimpseH4H
//

import Foundation

struct Room: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var imageData: [Data]  // 4–6 room photos
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        imageData: [Data] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.imageData = imageData
        self.createdAt = createdAt
    }
}
