//
//  PhotoLibraryLoader.swift
//  GlimpseH4H
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Transferable wrapper so PhotosPicker can load image data reliably.
struct ImageDataTransfer: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { ImageDataTransfer(data: $0) }
        DataRepresentation(importedContentType: .jpeg) { ImageDataTransfer(data: $0) }
        DataRepresentation(importedContentType: .png) { ImageDataTransfer(data: $0) }
    }
}

enum PhotoLibraryLoader {

    /// Loads images from PhotosPickerItem array and returns current images plus newly loaded ones (up to maxCount).
    static func loadImages(
        from items: [PhotosPickerItem],
        maxCount: Int,
        currentImages: [UIImage]
    ) async -> [UIImage] {
        var result = currentImages
        for item in items {
            guard result.count < maxCount else { break }
            if let transfer = try? await item.loadTransferable(type: ImageDataTransfer.self),
               let img = UIImage(data: transfer.data), result.count < maxCount {
                result.append(img)
            }
        }
        return result
    }
}
