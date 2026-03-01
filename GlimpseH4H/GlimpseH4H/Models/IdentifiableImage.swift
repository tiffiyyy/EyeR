//
//  IdentifiableImage.swift
//  GlimpseH4H
//
//  Wraps UIImage with a stable ID for SwiftUI ForEach and list operations.
//

import UIKit

struct IdentifiableImage: Identifiable {
    let id: UUID
    let image: UIImage

    init(id: UUID = UUID(), image: UIImage) {
        self.id = id
        self.image = image
    }
}
